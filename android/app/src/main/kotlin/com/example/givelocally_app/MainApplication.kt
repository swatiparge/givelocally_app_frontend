package com.example.givelocally_app

import android.app.Application
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // REMOVED: FirebaseApp.initializeApp(this) 
        // We let the Flutter side initialize Firebase to avoid [core/duplicate-app] errors.
        // The Flutter side initialization in main.dart is more reliable for plugin configuration.
    }
}
