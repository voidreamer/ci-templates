// CloudFront Function: preview-spa-rewrite
// Handles SPA routing for preview deployments under /pr-{number}/ prefixes.
//
// - /pr-42/                    -> /pr-42/index.html
// - /pr-42/dashboard           -> /pr-42/index.html
// - /pr-42/settings/profile    -> /pr-42/index.html
// - /pr-42/assets/main.js      -> /pr-42/assets/main.js  (passthrough)

function handler(event) {
  var request = event.request;
  var uri = request.uri;

  var match = uri.match(/^(\/pr-\d+)\//);

  if (match) {
    var prefix = match[1];
    var hasExtension = uri.split('/').pop().includes('.');
    if (!hasExtension) {
      request.uri = prefix + '/index.html';
    }
  } else if (uri === '/' || uri === '') {
    request.uri = '/index.html';
  }

  return request;
}
