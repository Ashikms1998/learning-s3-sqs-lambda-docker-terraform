// First understand what the code needs to do:

// 1. Receive SQS event 
// 2. Extract bucket name + file name from the event
// 3. Download the image FROM input S3 bucket
// 4. Resize it into 3 versions using Sharp
// 5. Upload all 3 versions TO output S3 bucket


const { S3Client, GetObjectCommand, PutObjectCommand } = require("@aws-sdk/client-s3");
const sharp = require("sharp");

// Connect to LocalStack S3 (not real AWS)
const s3 = new S3Client({
  region: "us-east-1",
  endpoint: process.env.S3_ENDPOINT || "http://host.docker.internal:4566",  // LocalStack URL from inside Docker
  forcePathStyle: true,                           // required for LocalStack
  credentials: {
    accessKeyId: "test",                          // LocalStack accepts any credentials
    secretAccessKey: "test"
  }
});

// The 3 sizes we will create
const SIZES = [
  { name: "small",  width: 320,  height: 320  },
  { name: "medium", width: 640,  height: 640  },
  { name: "large",  width: 1280, height: 1280 }
];

exports.handler = async (event) => {
  console.log("Lambda triggered!");
  console.log("Event:", JSON.stringify(event, null, 2));

  for (const sqsRecord of event.Records) {

    // Step 1: Parse SQS message body
    const body = JSON.parse(sqsRecord.body);

    // Skip S3 test events (sent when notification is first created)
    if (!body.Records) {
      console.log("Skipping non-S3 event (test event)");
      continue;
    }

    for (const s3Record of body.Records) {

      // Step 2: Extract file details
      const inputBucket = s3Record.s3.bucket.name;
      const fileName    = decodeURIComponent(s3Record.s3.object.key);

      console.log(`Processing: ${fileName} from ${inputBucket}`);

      // Step 3: Download image from S3 input bucket
      const getCommand = new GetObjectCommand({
        Bucket: inputBucket,
        Key: fileName
      });

      const s3Response = await s3.send(getCommand);

      // Convert S3 stream to buffer (raw bytes Sharp can work with)
      const imageBuffer = Buffer.concat(
        await s3Response.Body.toArray()
      );

      console.log(`Downloaded ${fileName} (${imageBuffer.length} bytes)`);

      // Step 4: Resize into 3 versions and upload each
      const outputBucket = process.env.OUTPUT_BUCKET;

      for (const size of SIZES) {
        console.log(`Resizing to ${size.name} (${size.width}x${size.height})`);

        // Resize using Sharp
        const resizedBuffer = await sharp(imageBuffer)
          .resize(size.width, size.height, {
            fit: "contain",       // keep aspect ratio, add padding if needed
            background: { r: 255, g: 255, b: 255, alpha: 1 }  // white background
          })
          .jpeg()                 // convert to jpeg
          .toBuffer();

        // Upload resized image to output bucket
        const outputKey = `resized/${size.name}/${fileName}`;

        const putCommand = new PutObjectCommand({
          Bucket: outputBucket,
          Key: outputKey,
          Body: resizedBuffer,
          ContentType: "image/jpeg"
        });

        await s3.send(putCommand);
        console.log(`Saved: s3://${outputBucket}/${outputKey}`);
      }

      console.log(`Done processing ${fileName}`);
    }
  }

  return {
    statusCode: 200,
    body: "Images resized successfully"
  };
};

// ### Two important things explained:

// **1. `host.docker.internal` instead of `localhost`:**

//   Lambda runs INSIDE a Docker container
//   Inside Docker, localhost = the container itself
//   NOT your machine

//   host.docker.internal = special Docker address
//                          "reach out to the HOST machine"
//                          host machine has LocalStack on :4566 ✅
// ```

// **2. `forcePathStyle: true`:**
// ```
// Normal S3 URL format:
//   bucket-name.s3.amazonaws.com/file.jpg
//   (bucket name in the domain)

// LocalStack URL format:
//   localhost:4566/bucket-name/file.jpg
//   (bucket name in the path)

// forcePathStyle = true → use LocalStack format ✅
// Without it → SDK tries bucket-name.localhost → fails ❌
// ```

// ---

// ### What Sharp's `fit: "contain"` does:
// ```
// Original image: 800x600 (landscape)
// Target size:    320x320 (square)

// fit: "contain" → shrink image to fit inside 320x320
//                  keep aspect ratio
//                  add white padding where needed

// Result:
// ┌─────────────────┐
// │  white padding  │
// │  ┌───────────┐  │
// │  │           │  │
// │  │  image    │  │
// │  │           │  │
// │  └───────────┘  │
// │  white padding  │
// └─────────────────┘
// 320x320 ✅

// Other options:
// fit: "cover"  → crop image to fill the box
// fit: "fill"   → stretch image to fill (looks distorted)