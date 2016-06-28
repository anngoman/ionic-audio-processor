
var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');


var AudioProcessor = function() {
};

AudioProcessor.close = function() {
    exec(null, null, "Keyboard", "close", []);
};

module.exports = AudioProcessor;



