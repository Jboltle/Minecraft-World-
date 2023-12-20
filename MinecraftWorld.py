import os
import subprocess
import time
from datetime import datetime

# GitHub App details
APP_ID = "722562"
CLIENT_ID = "Iv1.8343edfd38855a86"
PRIVATE_KEY_PATH = "/path/to/your/private-key.pem"
REPO = "Minecraft-World-"

# Local Minecraft server directory
SERVER_DIR = "/path/to/your/minecraft/server"

def commit_and_push_changes():
    # Commit and push changes to the local Git repository
    subprocess.run(["git", "-C", SERVER_DIR, "add", "."])
    subprocess.run(["git", "-C", SERVER_DIR, "commit", "-m", "Automated commit - {}".format(datetime.now())])
    subprocess.run(["git", "-C", SERVER_DIR, "push"])

def push_to_github():
    # Authenticate with GitHub App using the private key
    subprocess.run(["gh", "auth", "login", "--with-token"], input=open(PRIVATE_KEY_PATH).read().encode(), check=True)

    # Push changes to the GitHub repository
    subprocess.run(["gh", "repo", "clone", REPO])
    subprocess.run(["cp", "-r", SERVER_DIR + "/*", REPO])
    subprocess.run(["gh", "repo", "upload", "--repo", REPO, "--branch", "main"])

def main():
    try:
        while True:
            # Commit and push changes every hour
            commit_and_push_changes()
            push_to_github()
            time.sleep(3600)  # Sleep for one hour

    except KeyboardInterrupt:
        # Handle manual termination and push changes
        commit_and_push_changes()
        push_to_github()

if __name__ == "__main__":
    main()
