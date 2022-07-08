---
description: Connect to a self-hosted server and get access to its files and terminal.
---

# Connecting to a remote server (SSH/FTP)

### Set up your remote server

Before using this feature, you'll need to set up a ssh or ftp server on your computer or server. On a Mac, you can do this by enabling Remote Login and full disk access in the `Sharing` section of System Preferences.

![Enabling SSH server on a Mac](<../.gitbook/assets/image (6).png>)

### Set up a new remote in Code App

Open the remote section in the side bar and enter the server's information. Enable `Remember credentials` to use save the credentials. Code App will ask for Face ID or Touch ID authentication when you connect to the server again in the future.

![Setting up a new remote](<../.gitbook/assets/image (2).png>)

### Key Authentication

You might also want to use key authenctication instead of password. To do so, start by generate a SSH key by running `ssh-keygen` in the terminal.

The remote section will now show a `Show public key` button. Tap it and copy the public key to your remote server at `~/.ssh/authorized_keys`. You can open this file by running `open ~/.ssh/authorized_keys` in your remote server's terminal.

### Finishing up

Congratulations! You can now access the remote server's files and terminal.

{% hint style="info" %}
**Good to know:** Only SFTP server allows terminal access
{% endhint %}

![](../.gitbook/assets/image.png)

