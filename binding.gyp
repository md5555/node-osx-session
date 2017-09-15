{
  "targets": [
    {
       "target_name": "node-osx-session",

       "sources": [ "session.mm" ],

       "include_dirs": [
		"src",
		"System/Library/Frameworks/ScriptingBride.framework/Headers",
		"<!(node -e \"require('nan')\")"
	],

       "link_settings": {
		"libraries": [
			"-framework CoreFoundation",
			"-framework Foundation"
		]
	}
    }
  ]
}
