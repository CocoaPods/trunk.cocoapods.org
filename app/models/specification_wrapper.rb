require 'cocoapods-core'
require 'shellwords'
require 'timeout'

module Pod
  module TrunkApp
    class SpecificationWrapper
      def self.from_json(json)
        hash = JSON.parse(json)
        if hash.is_a?(Hash)
          new(Specification.from_hash(hash))
        end
      rescue JSON::ParserError
        # TODO: report error?
        nil
      end

      def initialize(specification)
        @specification = specification
      end

      def name
        @specification.name
      end

      def version
        @specification.version.to_s
      end

      def to_s
        @specification.to_s
      end

      def to_json(*a)
        @specification.to_json(*a)
      end

      def to_pretty_json(*a)
        @specification.to_pretty_json(*a)
      end

      def valid?(allow_warnings: false)
        linter.lint
        validate_prepare_command
        linter.results.send(:results).reject! do |result|
          result.type == :warning && result.attribute_name == 'attributes' && result.message == 'Unrecognized `pushed_with_swift_version` key.'
        end
        allow_warnings ? linter.errors.empty? : linter.results.empty?
      end

      def validation_errors(allow_warnings: false)
        results = {}
        results['warnings'] = remove_prefixes(linter.warnings) unless allow_warnings || linter.warnings.empty?
        results['errors']   = remove_prefixes(linter.errors)   unless linter.errors.empty?
        results
      end

      def publicly_accessible?
        return validate_http if @specification.source[:http]
        return validate_git if @specification.source[:git]
        return validate_hg if @specification.source[:hg]

        true
      end

      private

      def wrap_timeout(&blk)
        Timeout.timeout(5) do
          blk.call
        end
      rescue Timeout::Error
        false
      end

      def validate_http
        wrap_timeout { HTTP.validate_url(@specification.source[:http]) }
      end

      def validate_hg
        hg = @specification.source[:hg]
        return false if hg.start_with? '--'
        return false if hg.include? ' --'

        true
      end

      def validate_git
        # We've had trouble with Heroku's git install, see trunk.cocoapods.org/pull/141
        url = @specification.source[:git]

        # Ensure that we don't have folks making git exec commands via their git reference
        return false if url.start_with? '--'
        return false if url.include? ' --'

        return true unless url.include?('github.com/')

        owner_name = url.split('github.com/')[1].split('/')[0]
        repo_name = url.split('github.com/')[1].split('/')[1]
        return false unless owner_name && repo_name

        # Drop the optional .git reference in a url
        repo_name = repo_name[0...-4] if repo_name.end_with? '.git'

        # Use the GH refs API for tags and branches
        ref = 'refs/head'
        ref = "refs/tags/#{@specification.source[:tag]}" if @specification.source[:tag]
        ref = "refs/heads/#{@specification.source[:branch]}" if @specification.source[:branch]
        ref = "commits/#{@specification.source[:commit]}" if @specification.source[:commit]

        api_path = "https://api.github.com/repos/#{owner_name}/#{repo_name}/git/#{ref}"

        gh = GitHub.new(ENV['GH_REPO'], :username => ENV['GH_TOKEN'], :password => 'x-oauth-basic')
        wrap_timeout do
          req = gh.head(api_path)
          return true if req.success?

          # Did they rename, or send the repo elsewhere?
          if req.status_code == 301
            return gh.head(req.headers['location'][0]).success?
          else
            false
          end
        end
      end

      def validate_prepare_command
        return unless @specification.prepare_command
        return if ALLOWED_PREPARE_COMMAND_PODS.include?(name)

        linter.add_error(:prepare_command, "Adding a prepare_command for new pods is no longer allowed.")
      end

      ALLOWED_PREPARE_COMMAND_PODS = [
        "!ProtoCompiler",
        "!ProtoCompiler-gRPCCppPlugin",
        "!ProtoCompiler-gRPCPlugin",
        "AFNetworking",
        "AVOSCloud",
        "AVOSCloud-tvOS",
        "AVOSCloud-watchOS",
        "AVOSCloudCrashReporting",
        "AVOSCloudIM",
        "AVOSCloudSNS",
        "AXACOREMODULE",
        "AZSClient",
        "Accelerator",
        "ActorSDK-iOS",
        "AdColony",
        "AdjustIO",
        "Adobe-Marketing-Cloud-Mobile-Services",
        "AeroGear-OTP",
        "AliyunSlsObjc",
        "AliyunSlsObjc-Bell",
        "AliyunSlsObjc-hunter",
        "AnnotationInject",
        "AnyoneKit",
        "ApigeeiOSSDK",
        "Apollo",
        "AppCoreKit",
        "AppCoreKit-smorel",
        "AppFrameworkKit",
        "AppLovinMediationTargetVideoAdapter",
        "AppPaoPaoSDK",
        "AppleGuice",
        "ApproovURLSession",
        "Apptimize",
        "AssociatedObject",
        "AzureIoTHubClient",
        "AzureIoTHubServiceClient",
        "AzureIoTUtility",
        "AzureIoTuAmqp",
        "AzureIoTuMqtt",
        "AzureMacroUtils",
        "AzureuMockC",
        "BDLive",
        "BIJKPlayer",
        "BIJKPlayerFork",
        "BIJKPlayerPrivacy",
        "BREnvironment",
        "Backendless",
        "Backendless-Light",
        "Backendless-bis",
        "Backendless-ios-SDK",
        "Backtrace-PLCrashReporter",
        "Backtrack-iOS-SDK",
        "Baidu-Maps-iOS-SDK",
        "Baidu-Player",
        "BaiduBCECapture",
        "BaiduBCEPlayerFull",
        "BaiduBCEPlayerLSS",
        "BaiduBCEReader",
        "BaiduMapAPI",
        "BaiduMapKit-Modular",
        "BambuserPlayerSDK",
        "BaseDevtool",
        "BeKindRewind",
        "BitcoinCashKit",
        "BitcoinKit",
        "Bluepill",
        "BolddeskFramework",
        "BolddeskFrameworkApp",
        "BolddeskSDK",
        "Boost-For-Mobile",
        "BoringSSL",
        "BoringSSL-GRPC",
        "BouncyCastle-ObjC",
        "BugfenderSDK",
        "BuglyDynamic",
        "BuglyHotfixDynamic",
        "CAF",
        "CBLiteSwift",
        "CBitcoin",
        "CCSOAuth2SessionManager",
        "CDiscount",
        "CLOpenSSL",
        "CLOpenSSL-XCF",
        "CLOpenSSL-XCF-rad",
        "CNNCommonResource",
        "Calabash",
        "Calabash-ios",
        "CalabashTest",
        "CapellaClient-GRPC",
        "CardIO",
        "Charts",
        "ChatbotSDK-IBMWatsonSpeechToTextV1",
        "Cloudinary",
        "CocoaHook",
        "CocoaLibSpotify",
        "CocoaTest",
        "CoconutKit",
        "CodeTeleport",
        "Colatris",
        "ComScore",
        "ComScore-iOS",
        "CommonCryptoSwift",
        "CorePlot",
        "CryptoppECC",
        "CryptoppECC-CHeader",
        "Cuckoo",
        "CyndiLauper",
        "DAPI-GRPC",
        "DKIflyMSC",
        "DTCoreText",
        "DartCvIOS",
        "DartCvMacOS",
        "DashSharedCore",
        "DevMateKit",
        "DittoReactNativeIOS",
        "DoordeckSDK",
        "DoubleConversion",
        "Dynamic-OpenCV",
        "DynamicFramework",
        "ECGeTuiSDK",
        "EJDB2",
        "EMSDK",
        "EXPMatchers+FBSnapshotTest",
        "EasyAbout",
        "EthereumKit",
        "FIJKPlayer",
        "FTS3HTMLTokenizer",
        "Facebook-iOS-SDK",
        "FactoryFactory",
        "FactoryProvider",
        "Firebase",
        "FirebaseCrashlytics",
        "FirebaseFirestore",
        "FirebaseOSX",
        "Flipper-DoubleConversion",
        "Flipper-Glog",
        "Flutter",
        "FlutterCounterSDK",
        "FlutterIJK",
        "FlutterIJKFramework",
        "FlutterMacOS",
        "FootprintOnboardingComponents",
        "FunctionalBuilder",
        "FyberMediationFacebookAudienceNetwork",
        "GDataXML-HTML",
        "GHUnitIOS",
        "GHUnitOSX",
        "GMP-iOS",
        "GRKOpenSSLFramework",
        "GVRSDK",
        "Geth",
        "GethDevelop",
        "GirdersSwift",
        "GoSquared",
        "GooglePlacesRow",
        "GoogleProtobuf",
        "GoogleTest",
        "GoogleTestingFramework",
        "GuardianDynamic",
        "HDWallet",
        "Heimdall",
        "HockeySDK",
        "HockeySDK-Source",
        "HostMediaFramework",
        "HotReloadClient",
        "IBMWatsonSpeechToTextV1",
        "IBMWatsonTextToSpeechV1",
        "IDZSwiftCommonCrypto",
        "IFLYMSCC",
        "ILTestMessageApp",
        "IPtProxy",
        "IRBaseKit",
        "IW",
        "IconBadger",
        "Iconic",
        "Iconic-JX",
        "InMobiSDK",
        "Instabug",
        "J2ObjC",
        "J2ObjC-Framework",
        "J2ObjC101",
        "J2ObjC2-Framework",
        "JLBlueLink",
        "JSBTencentOpenAPI",
        "JSC-Polyfills",
        "Jansson",
        "Jargon",
        "JavaScriptCoreOpalAdditions",
        "JudoShield",
        "JuiceboxSdk",
        "Juspay-DoubleConversion",
        "Juspay-glog",
        "JustTweak",
        "K12FlutterPod",
        "KZPlayground",
        "KinSDK",
        "Kinvey",
        "KinveyKit",
        "KinveyResearchKit",
        "KumulosSdkObjectiveC",
        "KumulosSdkSwift",
        "LARSAdController",
        "LLSDK",
        "LRXF",
        "LYFUIKit",
        "LevelDB-ObjC",
        "LibComponentLogging-Core",
        "LibComponentLogging-Crashlytics",
        "LibComponentLogging-LogFile",
        "LibComponentLogging-NSLog",
        "LibComponentLogging-NSLogger",
        "LibComponentLogging-SystemLog",
        "LibComponentLogging-UserDefaults",
        "LibComponentLogging-qlog",
        "LibYAML",
        "Libssh2-iOS",
        "Libuv-gRPC",
        "LiquidCore",
        "LiquidCore-headers",
        "LiveMediaFramework",
        "LuaJIT",
        "LuaJIT-DynamOC",
        "Lynx",
        "LynxDevtool",
        "LynxService",
        "MIJKPlayer",
        "MMDB-Swift",
        "MMXXMPPFramework",
        "MNCAnalytics",
        "MTLManagedObjectAdapter",
        "Magnet-XMPPFramework",
        "MapBox",
        "MapLibraryWrapper",
        "MappableMobile",
        "Mapzen-ios-sdk",
        "MiniPlengi",
        "Mobicast",
        "MockReaderUI",
        "MockingbirdFramework",
        "MongoObjCDriver",
        "MongoSwift",
        "MongoSwiftMobile",
        "MuPDF",
        "MyScriptInteractiveInk-Runtime",
        "NBus",
        "NBusQQSDK",
        "NBusWechatSDK",
        "NBusWeiboSDK",
        "NEPlayer",
        "NIMSDK",
        "NRGramKit",
        "Natrium",
        "NetUtils",
        "NoctuaSDK",
        "NonaPics",
        "OKTY-Salesforce-iOS",
        "OSRMTextInstructions",
        "OTRKit",
        "OZLivenessSDK",
        "ObjectiveRocks",
        "OctoKit",
        "OderoPaySDKIOS",
        "OneTimePassword",
        "OpacityCore",
        "OpenAliPaySDK",
        "OpenCC",
        "OpenCV",
        "OpenCV-4.0.0-Beta",
        "OpenCV-Dynamic",
        "OpenCV-Dynamic-Framework",
        "OpenCV-iOS",
        "OpenCV-iOS-Serasa",
        "OpenCVBridge",
        "OpenSSL",
        "OpenSSL-Apple",
        "OpenSSL-Framework",
        "OpenSSL-OSX",
        "OpenSSL-VG",
        "OpenSSL-XM",
        "OpenSSL-for-agc-clouddb",
        "OpenSSL-for-iOS",
        "OpenSSL-iOS",
        "OpenSSL-iOS-Pod",
        "OpenSSLBitcode",
        "OpenWeChatSDK",
        "Optimizely-iOS-SDK",
        "PLCrashReporter-DynamicFramework",
        "PTSFramework",
        "PXBuildVersion",
        "Parse",
        "ParseCrashReporting",
        "ParseFacebookUtils",
        "ParseFacebookUtilsV4",
        "ParseTwitterUtils",
        "ParseUI",
        "Parsel",
        "PayPal-iOS-SDK",
        "Pixate",
        "PowerAnalytics",
        "PowerAuth2",
        "PowerAuth2-Debug",
        "PowerAuth2ForExtensions",
        "PowerAuth2ForWatch",
        "PowerAuthCore",
        "PulseReactiveC",
        "QJTencentOpenAPI",
        "QJWeChatSDK1",
        "R",
        "RACObjC",
        "RARegisterKit-Pangle",
        "Randient",
        "RaptureXML@Frankly",
        "React",
        "ReactantUI",
        "ReactiveCocoa",
        "ReactiveCocoaEx",
        "ReactiveCocoaLayout",
        "ReactiveObjC",
        "ReactiveObjCForTDesk",
        "ReactiveViewModel",
        "RealTimeCutVADLibrary",
        "Realm",
        "RealmSwift",
        "ReclaimInAppSdk",
        "RescueSDK",
        "RongCloud",
        "RongCloudIMKit",
        "RubyGateway",
        "RyuCrypto",
        "SCrypto",
        "SMART",
        "SOAYBPopupMenu",
        "SOAZHAutoSizeTagView",
        "SQLCipher",
        "SSToolkit",
        "SZAPITool",
        "SalesforceMobileSDK-iOS",
        "SampleKit",
        "SatispayInStore",
        "SinchVerification-Swift",
        "SinglySDK",
        "SmallStrings",
        "SmileIDSecurity",
        "SpaceflowFirebase",
        "Spotify-iOS-SDK",
        "Spotify-iOS-Streaming-SDK",
        "SpotifyAppRemoteSDK",
        "SquareMobilePaymentsSDK",
        "StitchAWSS3Service",
        "StitchAWSSESService",
        "StitchCore",
        "StitchCoreAWSS3Service",
        "StitchCoreAWSSESService",
        "StitchCoreFCMService",
        "StitchCoreHTTPService",
        "StitchCoreLocalMongoDBService",
        "StitchCoreRemoteMongoDBService",
        "StitchCoreSDK",
        "StitchCoreTwilioService",
        "StitchFCMService",
        "StitchHTTPService",
        "StitchLocalMongoDBService",
        "StitchRemoteMongoDBService",
        "StitchTwilioService",
        "StreamVideo",
        "StreamVideo-XCFramework",
        "Subliminal",
        "SupersonicAds",
        "SwSelect",
        "SwiftyCurl",
        "Symbol",
        "SynKit",
        "TIJKMediaPlayer",
        "TencentOpenAPI-Swift",
        "TencentOpenAPI_YH",
        "TencentOpenSDK-iOS",
        "TestmunkCalabash",
        "ThermodoSDK",
        "Three20",
        "ThumbprintTokens",
        "Tor",
        "TorchORM",
        "TouchDB",
        "TrezorCrypto",
        "TrezorFirmwareCrypto",
        "TrustWalletCore",
        "UIKitHotReload",
        "UTSIjkPlayer",
        "UTSIjkPlayerZF",
        "UnityAds",
        "UpsightKit",
        "UrbanAirship-iOS-SDK",
        "VisionCCiOSSDK",
        "WCDB",
        "WCDB.swift",
        "WCDB.swift_ct",
        "WCDBOptimizedSQLCipher",
        "WIJKPlayer",
        "WeChatQRCodeScanner",
        "WeChatQRCodeScanner_Swift",
        "WechatOpenSDK.swift",
        "WepinLogin",
        "Wilddog",
        "WilddogDatabase",
        "WilddogDatabasePre",
        "WilddogPre",
        "WilddogSync",
        "Wire",
        "WireCompiler",
        "WireGuardKit",
        "WormholeWilliam",
        "XIJKPlayer",
        "XMPPFramework",
        "XTInfiniteScrollView",
        "XpringKit",
        "YJCocoa",
        "YJTableViewFactory",
        "YTXModule",
        "YWTencentOpenAPI-Swift",
        "YWTencentSDK",
        "YWWBSDK",
        "YWWeChatSDK",
        "YandexMapsMobile",
        "YouTuEngineMediaPlayer",
        "YttriumWrapper",
        "YunoAntifraudClearsale",
        "YunoAntifraudOpenpay",
        "YunoSDK",
        "ZFFramework",
        "ZHAddressTextFiled",
        "ZHAutoSizeTagView",
        "ZHLocalizationStringMangerObjc",
        "ZHSegmentTagView",
        "ZXRMap",
        "ZYLDataBase",
        "ZappPushPluginPressengerPNCE",
        "ZappPushPluginPressengerPNSE",
        "ZappPushPluginPressengerPNSE_NoPNCE",
        "ZcashLightClientKit",
        "ZelloAPISwift",
        "apploggerSDK",
        "approov-service-nsurlsession",
        "apptheta",
        "aubio",
        "aubio-iOS",
        "aubio-iOS-SDK",
        "aubio-ios-2",
        "bitcoin-core-secp256k1",
        "bls-signatures-pod",
        "boost-iosx",
        "cagrpc",
        "chiatk-bls-signatures-pod",
        "chiatk-bls-signatures-shared-pod",
        "cmark",
        "cmark-bridge",
        "cmark-gfm",
        "ctemplate",
        "dlib",
        "dlibVzt",
        "dumb",
        "fplayer-core",
        "freexl",
        "gFramework",
        "gRPC",
        "gRPC-C++",
        "gRPC-Core",
        "geos",
        "glog",
        "hippy",
        "iHubSDK",
        "iOSBinaryPractice",
        "icu4c",
        "icu4c-iosx",
        "iflyMSCKit",
        "ijkmedia-framework",
        "imglyKit",
        "j2objc-pod",
        "jsoncpp",
        "kotlin_library",
        "lambert-objc",
        "libFFmpeg-iOS",
        "libavif",
        "libbcrypt",
        "libbpg",
        "libbson",
        "libcmark",
        "libcyassl",
        "libdav1d",
        "libde265",
        "libetpan",
        "libevent",
        "libflif",
        "libgurucv",
        "libheif",
        "libidn",
        "libjson",
        "libogg",
        "libopus",
        "libopus-patched-config",
        "libopus-rs",
        "libpng",
        "libpng-apng",
        "libqrencode",
        "librdf.ios",
        "librlottie",
        "libsasl2",
        "libscrypt",
        "libserialport",
        "libsodium",
        "libssh2-iosx",
        "libvorbis",
        "libwbxml",
        "libwebp",
        "libx265",
        "libxlsxwriter",
        "libzmq",
        "lua-iosx",
        "lz4-iosx",
        "lzma-iosx",
        "mailcore2",
        "mailcore2-ios",
        "mailcore2-osx",
        "mamaSDK",
        "measurement_kit",
        "mediasoup-ios-client",
        "mocean-sdk-ios",
        "mongo-c-driver",
        "morse",
        "mozjpeg",
        "msgpack",
        "node-sqlite3",
        "openssl-ios-bitcode",
        "openssl-ios-bitcode-ii",
        "openssl-iosx",
        "openssl-iosx-sy",
        "oxeplayer",
        "proj4",
        "proj4-ios",
        "protobuf-c",
        "razorpay-pod",
        "react-native-headers",
        "scriber",
        "secp256k1",
        "secp256k1.ph4.swift",
        "secp256k1_dash",
        "secp256k1_ios",
        "secp256k1_swift",
        "snappy-library",
        "snowball",
        "spatialite",
        "spectrum-folly",
        "sqlite3",
        "sqlite3_arabic_tokenizer",
        "sqlite3_distlib",
        "yajl",
        "zziplib",
      ].freeze
      private_constant :ALLOWED_PREPARE_COMMAND_PODS

      def linter
        @linter ||= Specification::Linter.new(@specification)
      end

      def remove_prefixes(results)
        results.map do |result|
          result.message.sub(/^\[.+?\]\s*/, '')
        end
      end
    end
  end
end
