
import 'dart:async';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

import 'maps/mapview001.dart';
import 'providers/geodata.dart';
import 'shared/appconfig.dart';
import 'package:flutter/material.dart';  
import 'package:confirm_dialog/confirm_dialog.dart';
import 'package:provider/provider.dart';  
import 'providers/mynotifier.dart';
import 'shared/globaldata.dart'; 
import 'helpers/helpers.dart';
import 'signin/signinpage.dart'; 
import 'views/views.dart';
import 'settings/settings_view.dart';
import 'api/api_auth.dart';
//  -------------------------------------    Root Page (Property of Nirvasoft.com)
class RootPage extends StatefulWidget {
  static const routeName = '/root';
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}
class _RootPageState extends State<RootPage> with WidgetsBindingObserver {
  late MyNotifier provider ;  // Provider Declaration and init
  final AuthServiceForGoogleLogin _authGoogleService = AuthServiceForGoogleLogin();
  //

  @override
  void initState() {          // Init
    super.initState(); 
    if (AppConfig.shared.log>=3) logger.i('Root initialized'); 
    provider = Provider.of<MyNotifier>(context,listen: false);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_){ 
      provider.updateData01(AppConfig.shared.appName, AppConfig.shared.appDesc);  // Provider update
    }); 

  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { // Lifecycle
    super.didChangeAppLifecycleState(state);
    if (AppConfig.shared.log>=3) logger.e("LifeCycle State: $state");
    if (state == AppLifecycleState.paused) {
      logger.e("Background");
      bg();
    }else if (state == AppLifecycleState.inactive) { bg();
    }else if (state == AppLifecycleState.resumed) { 
      logger.e("Foreground");
      ApiAuthService.checkRefreshToken();
    }
  }

  Future<void> bg() async {
    if (GeoData.tripStarted) {
      await GeoData.location.enableBackgroundMode(enable: true);
    } else {
      await GeoData.location.enableBackgroundMode(enable: false);
    }
  }

  @override
  Widget build(BuildContext context) {  // Widget
    return  Consumer<MyNotifier>(
      builder: (BuildContext context, MyNotifier value, Widget? child) {
      return 
        Scaffold(
          appBar: AppBar(
            title: Text(provider.data01.name), // Consumer
            actions: [
              PopupMenuButton<String>(          
                icon: const Icon(Icons.more_vert),
                onSelected: (value) { 
                  if (value == 'Item 1') {provider.updateData01('PRF', 'Profile 1');  } // Provider Update
                  else if (value == 'Item 2') {  provider.updateData01('STN', 'Profile 2'); } // Provider Update
                  else if (value =="settings"){  Navigator.restorablePushNamed(context, SettingsView.routeName);   }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>( value: 'Item 1',  child: Text('Profile 1'),  ),
                  const PopupMenuItem<String>( value: 'Item 2',  child: Text('Profile 2'), ),
                  const PopupMenuItem<String>( value: 'settings',  child: Text('Settings'), ),
                ],
              ),
            ],
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  padding: EdgeInsets.zero,
                  decoration: BoxDecoration(color: AppConfig.shared.primaryColor), //BoxDecoration
                  child: UserAccountsDrawerHeader(
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(color: AppConfig.shared.primaryColor),
                    accountName: Text(GlobalAccess.userName ?? '', style: const TextStyle(fontSize: 18)),
                    accountEmail: Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(GlobalAccess.email),
                          GestureDetector(
                            onTap: () {},
                            child: const Icon(Icons.edit_note_rounded),
                          ),
                        ],
                      ),
                    ),
                    currentAccountPictureSize: const Size.square(50),
                    currentAccountPicture: InkWell(
                      onTap: () { },
                      child: Stack(children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          backgroundImage: GlobalAccess.imgUrl != null ? NetworkImage(GlobalAccess.imgUrl!.isNotEmpty ? GlobalAccess.imgUrl! : "") : null,
                        ),
                      ]),
                    ), //circleAvatar
                  ),
                ),
                ListTile( title:  const Text('Home',), onTap: () async {MyHelpers.msg("You are home");},    ),
                ListTile( title:  Text('${GlobalAccess.mode=="Guest"?"Sign In":"Sign Out"} ',),  onTap: () async { _gotoSignIn(context); },),
              ],
            ),
          ),
          body: const DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      ViewApps(),
                      MapView001(),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab( text: 'Home', icon: Icon(Icons.home), ),
                    Tab( text: 'Map', icon: Icon(Icons.map), ),
                  ],
                ), 
              ],
            ),
          ),
        );
      }
    ); 
  }
  Future<void> _gotoSignIn(BuildContext context) async {
    if (GlobalAccess.mode != "Guest") { // if Users, need to confirm before signing out
      if (await confirm(context,title: const Text('Sign out'),content: Text('Would you like to sign out ${GlobalAccess.userName}?'),
        textOK: const Text('Yes'),textCancel: const Text('No'),)) {
        if(GlobalAccess.mode == "google"){
          await _authGoogleService.signOut();
        }else if(GlobalAccess.mode == "facebook"){
          await FacebookAuth.instance.logOut();
        }
        GlobalAccess.reset();               // reset global data
        await GlobalAccess.resetSecToken(); // reset secure storage with global data
        provider.updateData01("", "");    // clear provider on screen
        setState(() {  Navigator.pushReplacementNamed(context,SigninPage.routeName, );});
      }
    } else { // if guest, quickly go to sigin in
        GlobalAccess.reset();               // reset global data
        await GlobalAccess.resetSecToken(); // reset secure storage with global data
        provider.updateData01("", "");    // clear provider on screen
        setState(() {  Navigator.pushReplacementNamed(context,SigninPage.routeName, );});
    }
  }
} 