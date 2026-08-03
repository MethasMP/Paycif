#!/usr/bin/env node
const http = require('http');

let buffer = '';

process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buffer += chunk;
  let lines = buffer.split('\n');
  buffer = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const msg = JSON.parse(line);
      handleJsonRpc(msg);
    } catch (err) {
      // Ignore invalid JSON lines
    }
  }
});

function sendJsonRpc(msg) {
  process.stdout.write(JSON.stringify(msg) + '\n');
}

function checkFigmaOnline() {
  return new Promise((resolve) => {
    const req = http.request(
      'http://127.0.0.1:3845/mcp',
      { method: 'POST', timeout: 500, headers: { 'Content-Type': 'application/json' } },
      (res) => {
        resolve(true);
      }
    );
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.end(JSON.stringify({ jsonrpc: '2.0', id: 0, method: 'ping' }));
  });
}

function postToFigma(msg) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(msg);
    const req = http.request(
      'http://127.0.0.1:3845/mcp',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
        timeout: 5000,
      },
      (res) => {
        let body = '';
        res.on('data', (c) => body += c);
        res.on('end', () => {
          try {
            resolve(JSON.parse(body));
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', (e) => reject(e));
    req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });
    req.write(data);
    req.end();
  });
}

async function handleJsonRpc(msg) {
  const online = await checkFigmaOnline();

  if (online) {
    try {
      const res = await postToFigma(msg);
      if (res) {
        sendJsonRpc(res);
        return;
      }
    } catch (e) {
      // Fallback if request fails
    }
  }

  // Offline fallback mode
  if (msg.id !== undefined) {
    if (msg.method === 'initialize') {
      sendJsonRpc({
        jsonrpc: '2.0',
        id: msg.id,
        result: {
          protocolVersion: '2024-11-05',
          capabilities: { tools: {} },
          serverInfo: {
            name: 'figma-dev-mode-mcp-server',
            version: '1.0.0',
          },
        },
      });
    } else if (msg.method === 'tools/list') {
      sendJsonRpc({
        jsonrpc: '2.0',
        id: msg.id,
        result: {
          tools: [],
        },
      });
    } else if (msg.method === 'ping') {
      sendJsonRpc({
        jsonrpc: '2.0',
        id: msg.id,
        result: {},
      });
    } else {
      sendJsonRpc({
        jsonrpc: '2.0',
        id: msg.id,
        error: {
          code: -32601,
          message: 'Figma Desktop MCP server is offline. Open Figma Desktop App with Dev Mode MCP enabled to use this tool.',
        },
      });
    }
  }
}
