CONFIG = debug
PLATFORM_IOS = iOS Simulator,name=iPhone 13 Pro

test:
	xcodebuild test \
		-configuration $(CONFIG) \
		-scheme TCAUIKitNavigation \
		-destination platform="$(PLATFORM_IOS)"
