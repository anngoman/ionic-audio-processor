
var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');


var AudioProcessor = function() {
};

AudioProcessor.doIt = function(successCallback, errorCallback) {
  exec(successCallback, errorCallback, "AudioProcessor", "doIt", []]);
};

module.exports = AudioProcessor;



