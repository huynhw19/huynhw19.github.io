const { app, BrowserWindow, Menu, shell } = require('electron');
const path = require('node:path');

const CONFIGKIT_URL = 'https://huynhw19.github.io/';
app.setAppUserModelId('com.configkit.desktop');

function isSafeWebUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

function createWindow() {
  const window = new BrowserWindow({
    width: 1440,
    height: 940,
    minWidth: 900,
    minHeight: 650,
    show: false,
    title: 'ConfigKit',
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    backgroundColor: '#f5f7f6',
    autoHideMenuBar: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      spellcheck: true,
      partition: 'persist:configkit'
    }
  });

  window.once('ready-to-show', () => window.show());
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (isSafeWebUrl(url)) shell.openExternal(url);
    return { action: 'deny' };
  });

  window.webContents.on('will-navigate', (event, url) => {
    if (!isSafeWebUrl(url)) event.preventDefault();
  });

  window.webContents.on('page-title-updated', (event) => {
    event.preventDefault();
    window.setTitle('ConfigKit');
  });

  window.loadURL(CONFIGKIT_URL);
  return window;
}

const menu = Menu.buildFromTemplate([
  {
    label: 'ConfigKit',
    submenu: [
      { label: 'Home', click: () => BrowserWindow.getFocusedWindow()?.loadURL(CONFIGKIT_URL) },
      { type: 'separator' },
      { label: 'Quit', accelerator: 'Alt+F4', click: () => app.quit() }
    ]
  },
  {
    label: 'View',
    submenu: [
      { role: 'reload', label: 'Reload' },
      { role: 'forceReload', label: 'Force Reload' },
      { type: 'separator' },
      { role: 'resetZoom', label: 'Actual Size' },
      { role: 'zoomIn', label: 'Zoom In' },
      { role: 'zoomOut', label: 'Zoom Out' },
      { type: 'separator' },
      { role: 'togglefullscreen', label: 'Full Screen' },
      { role: 'toggleDevTools', label: 'Developer Tools' }
    ]
  },
  {
    label: 'Help',
    submenu: [
      { label: 'Open ConfigKit in Browser', click: () => shell.openExternal(CONFIGKIT_URL) },
      { label: 'About ConfigKit', click: () => shell.openExternal('https://huynhw19.github.io/how-to.html') }
    ]
  }
]);

app.whenReady().then(() => {
  Menu.setApplicationMenu(menu);
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
