import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart'; 

import '../helpers/env.dart';
import '../shared/appconfig.dart';
import '../shared/globaldata.dart';
//  -------------------------------------    API (Property of Nirvasoft.com)
class ApiAuthService {
  static String authURL = AppConfig.shared.authURL;     // config.env
  static String clientID = AppConfig.shared.clientID;   // config.env
  static String secretKey = AppConfig.shared.secretKey; // dart define
  final Logger logger = Logger();
  // 
  Future<Map<String, dynamic>> guestSignIn() async {
    //  MyHelpers.msg(secretKey,sec:5);
    final url = Uri.parse("$authURL/guest/login");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "client_id": clientID,
          "secret_key": secretKey,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        if (AppConfig.shared.log>=1) logger.e("Unauthorized Access (Guest): ${response.body}");
        return {"status": response.statusCode, "message": "Unauthorized Access (Guest)"};
      }
    } catch (e, stacktrace) {
      if (AppConfig.shared.log>=1) logger.e("Exception in guestLogin: $e\n$stacktrace");
      return {"status": 500, "message": "Exception in guestLogin: $e"};
    }
  }
  Future<Map<String, dynamic>> userSignIn(String username, String password) async {
    final url = Uri.parse("$authURL/user/login");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({ "user_id": username, "password": password,  }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        if (AppConfig.shared.log>=1) logger.e("Unautorized Access (Login): ${response.body}");
        return {"status": response.statusCode, "message": "Unauthorized Access (Login)"};
      }
    } catch (e, stacktrace) {
      if (AppConfig.shared.log>=1) logger.e("Other Exceptions (Login)): $e\n$stacktrace");
      return {"status": 500, "message": "Other Exceptions (Login): $e"};
    }
  }
  Future<Map<String, dynamic>> refreshTokenWith( String userId, String refreshToken) async {
    final url = Uri.parse("$authURL/generate/refreshToken");
    try {
      final response = await http.post(url,
        headers: {
          "Content-Type": "application/json",
          "access_id": userId,
          "refresh_token": refreshToken,
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        if (AppConfig.shared.log>=1) logger.e("Unauthorized Access (Refresh): ${response.body}");
        return { "status": response.statusCode, "message": "Unauthorized Access (Refresh)"};
      }
    } catch (e, stacktrace) {
      if (AppConfig.shared.log>=1) logger.e("Other Exceptions (Refresh)): $e\n$stacktrace");
      return {"status": 500, "message": "Other Exceptions (Refresh): $e"};
    }
  }
  static Future<bool> refreshToken() async {
    ApiAuthService apiAuthService = ApiAuthService(); 
    final apiAuthResponse = await apiAuthService.refreshTokenWith(GlobalAccess.userID, GlobalAccess.refreshToken);
    if (apiAuthResponse['status'] != 200) { 
      GlobalAccess.reset();
      GlobalAccess.resetSecToken();
      return false;
    } else {
      GlobalAccess.updateUToken(GlobalAccess.userID,GlobalAccess.userName,apiAuthResponse['data']['user_token'],GlobalAccess.refreshToken);
      GlobalAccess.updateSecToken();
      return true;
    }
  }

  static bool isTokenExpired(String token) {
    // client side code needed to check token expiry
    // decode token and check (Shwe Yi pls edit here)
    return token.isNotEmpty ? false : true;
  } 

  static Future<void> checkRefreshToken() async{
    if (ApiAuthService.isTokenExpired(GlobalAccess.accessToken)){ // local token checking
        ApiAuthService.refreshToken();
    }
  }
}

class AuthServiceForGoogleLogin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      GlobalAccess.updateUserInfo("","", "", "", googleAuth.accessToken!, googleAuth.idToken!);
      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      logger.i("Error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}