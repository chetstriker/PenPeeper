importScripts('https://cdn.jsdelivr.net/npm/sql.js@1.6.2/dist/sql-wasm.js');

const _debug = true;
let SQL;
let db;

self.addEventListener('message', async (event) => {
  const { data, ports } = event;
  const [responsePort] = ports;
  
  if (_debug) console.log('Worker received:', data);
  
  try {
    if (!SQL) {
      SQL = await initSqlJs({
        locateFile: file => `https://cdn.jsdelivr.net/npm/sql.js@1.6.2/dist/${file}`
      });
      db = new SQL.Database();
    }
    
    if (data.method === 'execute') {
      const result = db.exec(data.sql);
      responsePort.postMessage({ result });
    } else if (data.method === 'run') {
      db.run(data.sql, data.params || []);
      responsePort.postMessage({ result: { changes: db.getRowsModified() } });
    } else if (data.method === 'query') {
      const stmt = db.prepare(data.sql);
      const result = [];
      while (stmt.step()) {
        result.push(stmt.getAsObject());
      }
      stmt.free();
      responsePort.postMessage({ result });
    } else {
      responsePort.postMessage({ error: 'Unknown method: ' + data.method });
    }
  } catch (error) {
    if (_debug) console.error('Worker error:', error);
    responsePort.postMessage({ error: error.message });
  }
});