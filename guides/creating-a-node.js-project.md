---
description: In this guide, we will build a simple web server using Node.js and Express.
---

# Creating a Node.js project

### Creating a new folder

Let's start by creating a folder to organise our project. In the file explorer section, tap on the create folder button to create a new folder. Hold the folder cell and rename the folder. You can now assign as it as the workpalce folder.

![Assigning a folder as workplace folder](../.gitbook/assets/IMG\_0630.png)

### Installing npm modules

In this project, we will be using a third party npm module called `Express`. Install it by running `npm i express` in the terminal. You will now see a folder called `node_modules` that contains the module we just installed. Another file created is `package.json`, it stores the list of dependencies as well as other information of your project. You can learn more about npm here: [https://docs.npmjs.com/cli/v7/configuring-npm/package-json](https://docs.npmjs.com/cli/v7/configuring-npm/package-json)

### Implementing the server

Creating a web server using Express is super simple. Create a new file `index.js` and copy the following code.

```javascript
const express = require('express');

const app = express();
const port = 3000;

app.get('/', (req, res) => {
    res.send('Hello from Express')
})

app.listen(port, () => console.log(`app listening on port ${port}`))
```

Tap the run button on type `node index.js` in the terminal to run the server. Launch Safari side-by-side and visit `localhost:3000`. You now have yourself an Express server :).

![An express server running on Code App](<../.gitbook/assets/image (3) (2).png>)

To stop the server, press the stop (square) button located at the top right corner of the terminal tab.
