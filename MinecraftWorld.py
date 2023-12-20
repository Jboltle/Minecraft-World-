import os
import subprocess
import time
from datetime import datetime

# GitHub App details
APP_ID = "722562"
CLIENT_ID = "Iv1.8343edfd38855a86"
PRIVATE_KEY_PATH = "C:/Users/Jon/Desktop/Minecraft-World-/minecraft-world-autouploader.2023-12-19.private-key.pem"
REPO_NAME = "Minecraft-World-"

# Local Minecraft server directory
SERVER_DIR = "C:/Users/Jon/Desktop/Minecraft-World-/Minecraft Server"

def commit_and_push_changes():
    # Commit and push changes to the local Git repository
    subprocess.run(["git", "-C", SERVER_DIR, "add", "."])
    subprocess.run(["git", "-C", SERVER_DIR, "commit", "-m", "Automated commit - {}".format(datetime.now())])
    subprocess.run(["git", "-C", SERVER_DIR, "push"])

def push_to_github():
    # Authenticate with GitHub App using the private key
    subprocess.run(["gh", "auth", "login", "--with-token"], input=open(PRIVATE_KEY_PATH).read().encode(), check=True)

    # Push changes to the GitHub repository
    subprocess.run(["gh", "repo", "clone", REPO_NAME])
    subprocess.run(["cp", "-r", SERVER_DIR + "/*", REPO_NAME])
    subprocess.run(["gh", "repo", "upload", "--repo", REPO_NAME, "--branch", "main"])

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
    try:
        main()
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        # Ensure changes are pushed before exiting
        commit_and_push_changes()
        push_to_github()
