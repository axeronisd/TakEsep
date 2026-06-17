{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    
    // Hide the loading screen as soon as the engine is initialized
    var boot = document.getElementById('boot');
    if (boot) {
      boot.classList.add('hidden');
    }
    
    await appRunner.runApp();
  }
});
