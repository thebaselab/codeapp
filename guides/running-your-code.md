---
description: Learn to write and run programs using different programming languages.
---

# Running your code

Code App comes with many built-in languages including C++, Python and others. To see a full list, click the link below:

{% content-ref url="../extras/supported-languages.md" %}
[supported-languages.md](../extras/supported-languages.md)
{% endcontent-ref %}

### A Hello World program in Python

Let's start by creating a Python source file. Expand the file explorer side bar and select the new file icon (document with a plus icon). You can either use the built in template or enter a custom file name to create an empty file.

For now, let's use the built in template.

![Creating a new file](<../.gitbook/assets/image (3).png>)

You should now see the hello world program written in Python. Tap the play button to run it.&#x20;

![Runing a Hello World program in Python](<../.gitbook/assets/image (4).png>)

Congratulations! You now ran your first program on Code App.

### Python - Installing a third party module

Third party modules allow you to do awesome things, including making network requests to a webserver, drawing charts to analysis data, or downloading a YouTube video.&#x20;

Code App comes with the `pip` command in the terminal. To install a modules, just type `pip install <module name>` in the terminal.

{% hint style="info" %}
Note that not all modules work on Code App, see the [FAQ](../extras/frequently-asked-questions.md#my-favourite-npm-python-module-doesnt-work) for more.
{% endhint %}

In this example, we will try out the `requests` module. It allows Python to make network requests the web servers. Let's try to get the list of people currently in the space.

Tap on the chevron button to bring up the terminal and type `pip install requests` in the terminal.

![Installing requests](<../.gitbook/assets/image (1).png>)

Copy the following code to your source file and click run:

```python
import requests

res = requests.get('http://api.open-notify.org/astros.json')
print(res.text)
```

![Getting the list of all astronauts on ISS](<../.gitbook/assets/image (5).png>)

You now have a list of all astronauts currently on their mission in the space.
