{{flutter_js}}
{{flutter_build_config}}

// ── Indicador de carga visual ───────────────────────────────────────────────
const loading = document.createElement('div');
loading.id = 'flutter-loading';
loading.innerHTML = `
  <style>
    #flutter-loading {
      position: fixed; inset: 0;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      background: #f5f5f5;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      z-index: 9999;
    }
    #flutter-loading .spinner {
      width: 36px; height: 36px;
      border: 3px solid #e0e0e0;
      border-top-color: #1565C0;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    #flutter-loading p {
      margin-top: 16px;
      color: #666;
      font-size: 14px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
  <div class="spinner"></div>
  <p>Cargando inventario…</p>
`;
document.body.appendChild(loading);

// ── Carga sin service worker (evita caché obsoleta en GitHub Pages) ──────────
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    // Quitar el indicador de carga cuando Flutter toma el control
    const el = document.getElementById('flutter-loading');
    if (el) el.remove();
  }
});
