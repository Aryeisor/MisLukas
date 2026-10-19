package co.mislukas.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity: local_auth muestra el diálogo de desbloqueo del
// sistema (BiometricPrompt) como un fragmento (Fase 6C, docs/07 §7.7).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 13 o superior: la vista de recientes no guarda una captura
        // con datos. A diferencia de FLAG_SECURE, las capturas de pantalla
        // siguen permitidas (docs/08 §8.8.3). En versiones anteriores la app
        // pone su propia capa al pasar a inactiva.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }
}
