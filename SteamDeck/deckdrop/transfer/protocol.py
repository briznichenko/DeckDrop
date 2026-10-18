#
#  protocol.py
#  DeckDrop
#
#  Created by Andrii Bryzhnychenko on 10/17/26.
#

from __future__ import annotations

import hashlib
import hmac
import http.client
import ipaddress
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import ssl
import threading
from dataclasses import dataclass
from typing import Callable
from urllib.parse import urlsplit
import uuid


class TransferError(Exception):
    pass


class Cancelled(TransferError):
    pass


@dataclass(frozen=True)
class Pairing:
    host: str
    port: int
    token: str
    fingerprint: str

    @classmethod
    def parse(cls, invitation: str) -> Pairing:
        try:
            url = urlsplit(invitation.strip())
            host = str(ipaddress.IPv4Address(url.hostname or ""))
            port = url.port
            token, fingerprint = url.fragment.split(".")
            valid = (
                url.scheme == "deckdrop" and url.path in ("", "/") and not url.query
                and url.username is None and url.password is None
                and port is not None and 1 <= port <= 65535
                and re.fullmatch(r"[A-Za-z0-9_-]{43}", token)
                and re.fullmatch(r"[a-f0-9]{64}", fingerprint)
            )
            if not valid:
                raise ValueError
            return cls(host, port, token, fingerprint)
        except (ValueError, TypeError):
            raise TransferError("Paste the complete pairing link copied from Deck Drop on your Mac.") from None


class PinnedConnection(http.client.HTTPSConnection):
    def __init__(self, pairing: Pairing):
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        super().__init__(pairing.host, pairing.port, timeout=15, context=context)
        self.pairing = pairing

    def connect(self):
        super().connect()
        certificate = self.sock.getpeercert(binary_form=True)
        actual = hashlib.sha256(certificate).hexdigest()
        if not hmac.compare_digest(actual, self.pairing.fingerprint):
            self.close()
            raise TransferError("This Mac’s certificate does not match the pairing link. Copy a fresh link from your Mac.")


def relative_path(value: object) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\x00" in value or "\\" in value:
        raise TransferError("The Mac returned an invalid file path.")
    path = PurePosixPath(value)
    if path.is_absolute() or any(p in ("", ".", "..") for p in value.split("/")):
        raise TransferError("The Mac returned an unsafe file path.")
    return path


def validate_manifest(data: object) -> dict:
    if not isinstance(data, dict):
        raise TransferError("Invalid folder information from the Mac.")
    name = relative_path(data.get("name"))
    if len(name.parts) != 1:
        raise TransferError("Invalid shared folder name.")
    directories, files = data.get("directories"), data.get("files")
    if not isinstance(directories, list) or not isinstance(files, list) or len(directories) + len(files) > 100_000:
        raise TransferError("This folder has too many entries for this version of Deck Drop.")
    paths = set()
    file_paths = set()
    ids = set()
    for directory in directories:
        path = relative_path(directory)
        if path in paths:
            raise TransferError("The folder contains duplicate paths.")
        paths.add(path)
    for file in files:
        if not isinstance(file, dict):
            raise TransferError("Invalid file information.")
        path = relative_path(file.get("path"))
        size, identifier = file.get("size"), file.get("id")
        if type(size) is not int or not 0 <= size <= 2**63 - 1 or type(identifier) is not int or identifier < 0:
            raise TransferError("Invalid file size or identifier.")
        if path in paths or identifier in ids:
            raise TransferError("The folder contains duplicate files.")
        paths.add(path)
        file_paths.add(path)
        ids.add(identifier)
    if any(parent in file_paths for path in paths for parent in path.parents):
        raise TransferError("A file conflicts with a folder path.")
    return data


class Client:
    def __init__(self, pairing: Pairing, cancelled: threading.Event | None = None):
        self.pairing = pairing
        self.cancelled = cancelled or threading.Event()

    def check_cancelled(self):
        if self.cancelled.is_set():
            raise Cancelled("Copy cancelled. Completed files are kept in the incomplete folder.")

    def request(self, path: str):
        self.check_cancelled()
        connection = PinnedConnection(self.pairing)
        try:
            connection.request("GET", path, headers={"Authorization": f"Bearer {self.pairing.token}"})
            response = connection.getresponse()
            if response.status == 401:
                raise TransferError("Sharing stopped or this link expired. Start sharing on the Mac and copy its new link.")
            if response.status != 200:
                raise TransferError(f"The Mac could not send this file (HTTP {response.status}). Start a new sharing session.")
            return connection, response
        except BaseException:
            connection.close()
            raise

    def manifest(self) -> dict:
        connection, response = self.request("/manifest")
        try:
            data = response.read(16 * 1024 * 1024 + 1)
            self.check_cancelled()
            if len(data) > 16 * 1024 * 1024:
                raise TransferError("This folder listing is too large for this version of Deck Drop.")
            try:
                return validate_manifest(json.loads(data))
            except (json.JSONDecodeError, UnicodeDecodeError):
                raise TransferError("The Mac returned invalid folder information.") from None
        finally:
            connection.close()

    def download(self, manifest: dict, destination: Path, progress: Callable[[int, int, str], None]) -> Path:
        manifest = validate_manifest(manifest)
        destination = destination.expanduser().resolve(strict=True)
        if not destination.is_dir():
            raise TransferError("Choose a destination folder first.")
        total = sum(file["size"] for file in manifest["files"])
        if shutil.disk_usage(destination).free < total:
            raise TransferError("There is not enough free space in the selected destination.")
        self.check_cancelled()
        staging = destination / f"{manifest['name']}.incomplete-{uuid.uuid4().hex[:8]}"
        staging.mkdir(mode=0o700)
        completed = 0
        try:
            for directory in manifest["directories"]:
                self.check_cancelled()
                self.safe_target(staging, directory).mkdir(parents=True, exist_ok=True)
            for file in manifest["files"]:
                self.check_cancelled()
                target = self.safe_target(staging, file["path"])
                target.parent.mkdir(parents=True, exist_ok=True)
                partial = target.with_name(f".deckdrop-{uuid.uuid4().hex}.partial")
                connection, response = self.request(f"/files/{file['id']}")
                try:
                    if response.getheader("Content-Length") != str(file["size"]):
                        raise TransferError("The shared folder changed. Start a new sharing session on the Mac.")
                    received = 0
                    with partial.open("xb") as output:
                        while received < file["size"]:
                            self.check_cancelled()
                            chunk = response.read(min(262_144, file["size"] - received))
                            if not chunk:
                                raise TransferError("Connection interrupted. The folder is incomplete; reconnect and try again.")
                            output.write(chunk)
                            received += len(chunk)
                            progress(completed + received, total, file["path"])
                        self.check_cancelled()
                        output.flush()
                        os.fsync(output.fileno())
                    partial.rename(target)
                    completed += received
                    progress(completed, total, file["path"])
                finally:
                    connection.close()
                    partial.unlink(missing_ok=True)
            self.check_cancelled()
            final = destination / manifest["name"]
            index = 2
            while True:
                try:
                    final.mkdir(mode=0o700)
                    break
                except FileExistsError:
                    final = destination / f"{manifest['name']} ({index})"
                    index += 1
            try:
                staging.rename(final)
            except BaseException:
                try:
                    final.rmdir()
                except OSError:
                    pass
                raise
            progress(total, total, "Done")
            return final
        except BaseException as error:
            if isinstance(error, Cancelled):
                raise
            raise TransferError(f"{error}\nIncomplete files: {staging}") from error

    @staticmethod
    def safe_target(root: Path, relative: str) -> Path:
        target = root.joinpath(*relative_path(relative).parts)
        if not target.resolve().is_relative_to(root.resolve()):
            raise TransferError("A destination path leaves the selected folder.")
        return target
