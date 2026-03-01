import 'dotenv/config';
import app, { port, onServerStarted, setupProcessHandlers, attachWebSocketServers } from './app.js';

const server = app.listen(port, () => {
  onServerStarted();
});

setupProcessHandlers();
attachWebSocketServers(server);
