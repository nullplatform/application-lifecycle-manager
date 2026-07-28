#!/usr/bin/env python3
"""Print a GitHub App JWT signed with the App's private key.

The agent image ships no openssl binary, and openssl is available neither through mise nor
through the image's apk index, so the JWT is built here instead of in the shell.

Reads GITHUB_APP_ID and GITHUB_PRIVATE_KEY from the environment and writes the JWT to stdout.
"""

import base64
import json
import os
import sys
import time

try:
	from cryptography.hazmat.primitives import hashes, serialization
	from cryptography.hazmat.primitives.asymmetric import padding
except ImportError:
	sys.exit("ERROR: the python 'cryptography' package is required to sign the GitHub App JWT.")

# GitHub rejects a JWT that expires more than 10 minutes after it was issued, and backdating the
# issued-at claim absorbs clock skew between this host and GitHub.
ISSUED_AT_SKEW_SECONDS = 60
EXPIRES_IN_SECONDS = 540


def b64url(raw: bytes) -> str:
	return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def encode_segment(segment: dict) -> str:
	return b64url(json.dumps(segment, separators=(",", ":")).encode())


def require_env(name: str) -> str:
	value = os.environ.get(name)

	if not value:
		sys.exit(f"ERROR: {name} is required to sign the GitHub App JWT but is not set.")

	return value


def load_private_key(pem: str):
	# A key stored in an environment variable may carry escaped newlines instead of real ones.
	try:
		return serialization.load_pem_private_key(pem.replace("\\n", "\n").encode(), password=None)
	except Exception as error:
		sys.exit(f"ERROR: GITHUB_PRIVATE_KEY is not a valid private key: {error}")


def main() -> None:
	app_id = require_env("GITHUB_APP_ID")
	key = load_private_key(require_env("GITHUB_PRIVATE_KEY"))

	now = int(time.time())
	unsigned = "{}.{}".format(
		encode_segment({"alg": "RS256", "typ": "JWT"}),
		encode_segment({"iat": now - ISSUED_AT_SKEW_SECONDS, "exp": now + EXPIRES_IN_SECONDS, "iss": app_id}),
	)

	signature = key.sign(unsigned.encode(), padding.PKCS1v15(), hashes.SHA256())

	print(f"{unsigned}.{b64url(signature)}")


if __name__ == "__main__":
	main()
