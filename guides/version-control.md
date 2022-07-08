---
description: Use the built-in support for Git to manage your code.
---

# Version Control

### Setup your identities

Git uses your username and email address identify the author of every commit. Before making a commit, you'll need to set up your identity.

To proceed, go `Settings > Version Control > Identity`.&#x20;

### Setup your credentials

Git providers usually require credentials before you can clone any repository. To start, setup your credentials at `Settings > Version Control > Authentication`.

In many cases, you'll need to generate a personal access token instead of using the regular password. To know more about this:

{% embed url="https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token" %}
Creating a personal access token on GitHub
{% endembed %}

{% embed url="https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html" %}
Creating a personal access tokeno on GitLab
{% endembed %}

### Cloning a repository

To clone a repository, select version control on the side bar. Either enter the repository's url or search a repo on GitHub by typing the keywords into the search field.

Currently, only HTTPS urls are supported.

### Commiting files

Newly added / modified files need to be added to the staging area before you can make a commit. To do it. press the plus icon next to the file name.

![Adding a file to staging area](<../.gitbook/assets/image (1) (1).png>)

You can now enter a commit message in the textfield and press the check button. You can also use the `command`+`enter` shortcut.

### Pushing to remote

You can now push you changes to your remote like GitHub.

![Pushing changes to remote](<../.gitbook/assets/image (3) (1).png>)

### Switching branches

To switch between branches, hold the branch icon located in the bottom left corner and select a branch.

![Checkout to a branch](../.gitbook/assets/image.png)

