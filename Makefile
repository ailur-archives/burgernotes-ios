ipa:
	@echo "Cleaning .burgernotes directory..."
	@rm -rfv .burgernotes/
	@mkdir -p .burgernotes/ipa
	@mkdir -p .burgernotes/archive
	@echo "Beginning build..."
	@xcodebuild -project Burgernotes.xcodeproj -scheme Burgernotes -sdk iphoneos -archivePath .burgernotes/archive/Payload CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO archive
	@echo ""
	@echo ""
	@echo "Archiving .ipa..."
	@mv .burgernotes/archive/Payload.xcarchive/Products/Applications .burgernotes/archive/Payload.xcarchive/Products/Payload
	@cd .burgernotes/archive/Payload.xcarchive/Products/ && zip -r ../../../ipa/Burgernotes.ipa Payload
	@echo "Done! ipa stored in .burgernotes/ipa."

all: ipa
