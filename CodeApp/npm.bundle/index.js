const http = require('http');
const url = require('url');
const EventEmitter = require('events').EventEmitter;
const npm = require('npm');

process.stdout.write = process.stderr.write = writeOutput;

var stdioEvent = new EventEmitter();

function writeOutput(buffer, encoding, callback){
  if (typeof chunk === 'string'){
    stdioEvent.emit('stdout',  buffer);
    return;
  }else{
    stdioEvent.emit('stdout', buffer.toString());
  }
}

process.on('SIGINT', doNothing);

function doNothing(){
  return
}

npm.load(() => {
    
  http.createServer(async function (req, res) {
    var params = url.parse(req.url, true).query;
    var pathname = url.parse(req.url, true).pathname;

    console.log(`Received url: ${req.url}`);

    function writeToResponse(mes){
      if (mes){
        res.write(mes);
      }
    }

    stdioEvent.on('stdout', writeToResponse);

    res.writeHead(200);

    if (params.root != null){
      npm.config.set('prefix', params.root)
      // npm.config.set('usage', false, 'cli');
      // process.chdir(params.root)
    }

    if (params.args == null){
      await runCommand([]);
    }else if (Array.isArray(params.args)){
      await runCommand(params.args)
    }else{
      await runCommand([params.args]);
    }

    stdioEvent.removeListener("stdout", writeToResponse);

//    res.write("ok");
    res.end();
  }).listen(9992)
});

async function runCommand(argv){
  isRunning = true;
  return new Promise(resolve => {
    const cmd = argv.shift();

    // stdioEvent.emit('stdout', `Command: ${cmd}`);

    const impl = npm.commands[cmd];

    function errorHandler(er, data) {
      if (er){
        stdioEvent.emit('stdout', er.message);
      }
      isRunning = false;
      resolve('resolved');
    }

    if (impl){
      impl(argv, errorHandler);
    }else{
      npm.config.set('usage', false)
      argv.unshift(cmd);
      npm.commands.help([cmd], errorHandler);
    }
  });
}
