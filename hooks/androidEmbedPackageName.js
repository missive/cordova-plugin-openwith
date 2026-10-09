const ACTIVITY_PATH = './platforms/android/app/src/main/java/com/missiveapp/openwith/OpenWithActivity.java';

const fs = require('fs');
const path = require('path');

const {
  redError,
} = require('./utils')

module.exports = function(context) {
  var deferral = require('q').defer();

  var parser = context.requireCordovaModule('cordova-common').ConfigParser;
  var config = new parser("config.xml");
  var packageName = config.android_packageName() || config.packageName();

  fs.readFile(ACTIVITY_PATH, 'utf8', function (err,data) {
    if (err) {
      throw redError(err.message);
    }

    var result = data.replace(/##ANDROID_PACKAGE_NAME##/g, packageName);

    fs.writeFile(ACTIVITY_PATH, result, 'utf8', function (err) {
      if (err) {
        throw redError(err.message);
      }
      deferral.resolve();
    });
  });

  return deferral.promise;
};
