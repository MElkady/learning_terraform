const AWS = require("aws-sdk");
const s3 = new AWS.S3();

exports.handler = async function (event) {
  console.log("EVENT: \n" + JSON.stringify(event, null, 2));
  return s3.listBuckets().promise();
};
