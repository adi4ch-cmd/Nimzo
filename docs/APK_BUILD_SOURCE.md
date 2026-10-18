# NIMZO APK source

The permanent APK source branch is `feature/profile-reference-redesign`. Default-branch Android workflows check out this branch so future builds include the private gift player and room event routing. Keep future app changes on this branch or merge them into it before release.

The four approved gift media files stay in the private Supabase bucket and are fetched through the authenticated gift-media gateway. No raw private gift videos are bundled in the APK. Gift availability and prices come from the server catalog.

No APK is built by this configuration update. Start the desired manual workflow when a build is requested. Old workflows dispatched from historical branches use their historical source and are not the supported release path.
