import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latlong2/latlong.dart';
import 'package:team_tracking/data/entity/activities.dart';
import 'package:team_tracking/data/entity/user_manager.dart';
import 'package:team_tracking/ui/views/activities_screen/activity_members_screen.dart';
import 'package:team_tracking/ui/views/homepage/homepage.dart';
import 'package:team_tracking/ui/views/login_screen/login_screen.dart';
import 'package:image/image.dart' as img;
import 'package:team_tracking/ui/views/main.dart';
import 'package:team_tracking/utils/constants.dart';

import '../entity/users.dart';

class ActivityTrackingDaoRepository {

  static ActivityTrackingDaoRepository shared = ActivityTrackingDaoRepository();

  //Dikkat: firestore kullanırken arayüzde veri güncelleme yapan metodları
  // (kisileriYukle ve kisiAra gibi) repoda yapıp return edemiyoruz.
  // Direk anasayfa_cubit içerisinde bu metodları yazıyoruz.


  final userCollection = FirebaseFirestore.instance.collection("users");
  final activityCollection = FirebaseFirestore.instance.collection("activities");
  final firebaseAuth = FirebaseAuth.instance;
  double _lastSpeed = 0;

  Future<LatLng> getLocation() async{
    LocationPermission permission;
    permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    LatLng firstPositon = LatLng(position.latitude, position.longitude);
    print(position); //here you will get your Latitude and Longitude
    return firstPositon;
  }

  //TODO: Sign up with email and password
  Future<void> signUp(BuildContext context, {required String name, required String email, required String password}) async {
    try {
      final UserCredential userCredential = await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
      LatLng position = await getLocation();
      await _registerUser(
        uid: userCredential.user!.uid,
        name: name ?? "unnamed",
        email: email,
        photoUrl: "",
        position: LatLng(position.latitude, position.longitude),
      );
      await handleUserSignIn(context, userCredential);
    } on FirebaseAuthException catch (e) {
      handleAuthException(context, e);
    } catch (e) {
      // Diğer hatalar
    }
  }

  //TODO: Sign in with email and password
  Future<void> signIn(BuildContext context, {required String email, required String password}) async {
    try {
      final UserCredential userCredential = await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      await handleUserSignIn(context, userCredential);
      if(userCredential.user != null){
        await updateUserLocation(userId: userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      handleAuthException(context, e);
    } catch (e) {
      print(e);
    }
  }

  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // Kullanıcı işlemi iptal etti.
        return null;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser == true) {
        // Yeni kaydedilen kullanıcı
        log("New user signed in with Google: ${userCredential.user?.displayName}");

        // Yeni kullanıcıya dair işlemleri burada yapabilirsiniz.
        LatLng position = await getLocation();
        await _registerUser(
          uid: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? "unnamed",
          email: userCredential.user!.email ?? "noEmail",
          photoUrl: "",
          position: LatLng(position.latitude, position.longitude),
        );
      } else {
        // Zaten kayıtlı olan kullanıcı
        log("Existing user signed in with Google: ${userCredential.user?.displayName}");
      }

      // Kullanıcı girişini handle et
      await handleUserSignIn(context, userCredential);

      return userCredential.user;
    } catch (e) {
      // Hata durumunda handle et
      print("Error signing in with Google: $e");
      //handleAuthException(context, e);
      return null;
    }
  }

  //TODO: Handle Mettods for sig in and sign up
  Future<void> handleUserSignIn(BuildContext context, UserCredential userCredential) async {
    if (userCredential.user != null) {
      Map<String, dynamic>? userData = await getUserData();
      if (userData != null) {
        Users curentUser = Users.fromMap(userCredential.user!.uid, userData);
        await UsersManager().setUser(curentUser);
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const Homepage(),));
      }
    } else {
      print(" kullanıcı bilgisi alnımadı ve set edilemedi");
    }
  }
  void handleAuthException(BuildContext context, FirebaseAuthException e) {
    Fluttertoast.showToast(msg: e.message!, toastLength: Toast.LENGTH_LONG);
  }

  //TODO: Sign Out Method
  Future<void> signOut(BuildContext context) async {
    try {
      _updateMyLocationTimer?.cancel();//konum göndermeyi durdur
      await firebaseAuth.signOut();
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => const MyApp()));
    } on FirebaseAuthException catch(e) {
      Fluttertoast.showToast(msg: e.message!, toastLength: Toast.LENGTH_LONG);
    }
  }

  //TODO: Get User Data
  Future<Map<String, dynamic>?> getUserData() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance.collection("users").doc(currentUser.uid).get();
      if (snapshot.exists) {
        String id = snapshot.id;
        Map<String, dynamic>? userData = snapshot.data();
        print("Current User data firebaseden çekildi");
        return userData;
      } else {
        // Kullanıcı bulundu, ancak veri bulunamadı.
        print("Kullanıcı bulundu, ancak veri bulunamadı.");
        return null;
      }
    } else {
      // Kullanıcı bulunamadı.
      print("Kullanıcı bulunamadı.");
      return null;
    }
  }


  //TODO Register user to firestore
  Future<void> _registerUser({required String uid, required String name, required String email, required String photoUrl, required LatLng position}) async {
    DateTime now = DateTime.now();
    var newUser = {
      "name": name,
      "email": email,
      "photoUrl": photoUrl,
      "phone": "",
      "lastLocation": {
        "latitude": position.latitude,
        "longitude": position.longitude,
      },
      "lastLocationUpdatedAt": now,
      "lastSpeed": 0.1,
    };
    await userCollection.doc(uid).set(newUser);
  }

  //TODO Register Activity to the firestore
  Future<void> registerActivity(
      {
        required String name,
        required String city,
        required String country,
        required String owner,
        required List<String> memberIds,
        String? photoUrl,
        List<String>? joinRequests,
      }) async {
    var newActivity = {
      "name": name,
      "city": city,
      "country": country,
      "owner": owner,
      "memberIds": memberIds,
      "photoUrl": photoUrl,
      "joinRequests": joinRequests,
    };
    await activityCollection.doc().set(newActivity);
  }

  //TODO Update User location in to firestore
  Future<void> updateUserLocation({required String userId}) async {
    LatLng position = await getLocation();
    var updatedData = {
      "lastLocation": {
        "latitude" : position.latitude,
        "longitude": position.longitude
      },
      "lastLocationUpdatedAt": DateTime.now()
    };
    await userCollection.doc(userId).update(updatedData);
    print("location updated: ${position.latitude} , ${position.longitude}");
  }

  //TODO Update Activity in the firestore
  Future<void> updateActivity(
      {
        required String activityId,
        required String name,
        required String city,
        required String country,
        String? photoUrl
      }) async {
    var updatedData = {
      "name": name,
      "city": city,
      "country": country,
      "photoUrl": photoUrl,
    };
    await activityCollection.doc(activityId).update(updatedData);
  }

  //TODO Update User in the firestore
  Future<void> updateUser(
      {
        required String userId,
        required String name,
        required String phone,
        String? photoUrl
      }) async {
    var updatedData = {
      "name": name,
      "phone": phone,
      "photoUrl": photoUrl,
    };
    await userCollection.doc(userId).update(updatedData);
  }

  //TODO Delete Activity from the firestore
  Future<void> deleteActivityFromFirestore({
    required String activityId,
    required String photoUrl,
  }) async {
    try {
      await activityCollection.doc(activityId).delete();
      print("Activity deleted successfully!");
      await deleteActivityImage(photoUrl);
    } catch (error) {
      print("Error deleting activity: $error");
      // Hata durumunda gerekli işlemleri yapabilirsiniz.
    }
  }



  Future<void> createActivity({
    required BuildContext context,
    required String name,
    required String city,
    required String country,
    required File? activityImage,
  }) async {
    if (name.isEmpty || city.isEmpty || country.isEmpty) {
      // Delay the execution of the dialog to allow the saveActivity method to complete
      await Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: kSecondaryColor2,
              title: const Text("Warning",style: TextStyle(color: Colors.white),),
              content: const Text("Please fill in all fields!",style: TextStyle(color: Colors.white),),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop;
                  },
                  child: const Text("OK",style: TextStyle(color: Colors.white),),
                ),
              ],
            );
          },
        );
      });
    } else {
      //Upload activity image
      String imageUrl = "";
      if (activityImage != null) {
        imageUrl = await uploadActivityImage(activityImage);
      }
      //Register activity to firestore
      String owner = UsersManager().currentUser!.id;
      List<String> memberIds = [UsersManager().currentUser!.id];
      List<String> joinRequests = [];
      registerActivity(
        name: name,
        city: city,
        country: country,
        owner:  owner,
        memberIds: memberIds,
        photoUrl: imageUrl,
        joinRequests: joinRequests,
      );
      // After the activity is saved, navigate back to the ActivitiesScreen
      Navigator.pop(context);
    }
  }

  Future<void> editActivity({
    required BuildContext context,
    required String activityId,
    required String name,
    required String city,
    required String country,
    File? activityImage,
    String? photoUrl,
  }) async {
    if (name.isEmpty || city.isEmpty || country.isEmpty) {
      // Delay the execution of the dialog to allow the saveActivity method to complete
      await Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: kSecondaryColor,
              title: const Text("Warning",style: TextStyle(color: Colors.white),),
              content: const Text("Please fill in all fields!",style: TextStyle(color: Colors.white),),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("OK",style: TextStyle(color: Colors.white),),
                ),
              ],
            );
          },
        );
      });
    } else {
      //Upload activity image
      String imageUrl = photoUrl ?? "";
      if (activityImage != null) {
        deleteActivityImage(photoUrl ?? "");
        imageUrl = await uploadActivityImage(activityImage);
      }
      //Update activity in firestore
      String currentUser = UsersManager().currentUser!.id;
      List<String> memberIds = [UsersManager().currentUser!.id];
      updateActivity(
        activityId: activityId,
        name: name,
        city: city,
        country: country,
        photoUrl: imageUrl,
      );
      // After the activity is saved, navigate back to the ActivitiesScreen
      Navigator.pop(context);
    }
  }

  Future<void> editUser({
    required BuildContext context,
    required String userId,
    required String name,
    required String phone,
    File? userImage,
    String? photoUrl,
  }) async {
    if (name.isEmpty){
      // Delay the execution of the dialog to allow the saveUser method to complete
      await Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: kSecondaryColor,
              title: const Text("Warning",style: TextStyle(color: Colors.white),),
              content: const Text("Please fill in all fields!",style: TextStyle(color: Colors.white),),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("OK",style: TextStyle(color: Colors.white),),
                ),
              ],
            );
          },
        );
      });
    } else {
      //Upload user image
      String imageUrl = photoUrl ?? "";
      if (userImage != null) {
        deleteUserImage(photoUrl ?? "");
        imageUrl = await uploadUserImage(userImage);
      }
      //Update user in firestore
      List<String> memberIds = [UsersManager().currentUser!.id];
      updateUser(
        userId: userId,
        name: name,
        phone: phone,
        photoUrl: imageUrl,
      );
      //get updated user data
      DocumentSnapshot<Map<String, dynamic>> snapshot =
      await FirebaseFirestore.instance.collection("users").doc(userId).get();
      if (snapshot.exists) {
        String id = snapshot.id;
        Map<String, dynamic>? userData = snapshot.data();
        Users updatedUser = Users.fromMap(id, userData!);
        await UsersManager().setUser(updatedUser);
        print("Current User set edildi");
      } else {
        print("Kullanıcıya ait  veri bulunamadı.");
      }
      // After the user is saved, navigate back to the ActivityMemberScreen
      Navigator.pop(context);
    }
  }

  Future<void> deleteActivity({
    required BuildContext context,
    required String activityId,
    required String photoUrl,
  }) async {
      // Delay the execution of the dialog to allow the saveActivity method to complete
      await Future.delayed(Duration.zero, () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: kSecondaryColor,
              title: const Text("Warning",style: TextStyle(color: kSecondaryColor2),),
              content: const Text("Are you sure you want to delete this activity?",style: TextStyle(color: Colors.white),),
              actions: [
                TextButton(
                  onPressed: () {
                    deleteActivityFromFirestore(activityId: activityId, photoUrl: photoUrl);
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text("Delete",style: TextStyle(color: Colors.red),),
                ),
              ],
            );
          },
        );
      });
    }


  //TODO: Upload Activity image to firebase storage
  Future<String> uploadActivityImage(File imageFile) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      String? userName = FirebaseAuth.instance.currentUser?.displayName ?? "";
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'activity_images/${userId}_$userName/$timestamp.jpeg';

      // Upload the resized image to Firebase Storage
      File resizedImageFile = await resizeImage(imageFile, 200, 200);
      await FirebaseStorage.instance.ref(fileName).putFile(resizedImageFile);

      // Get the download URL of the uploaded image
      String imageUrl = await FirebaseStorage.instance.ref(fileName).getDownloadURL();

      return imageUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return "";
    }
  }

  //TODO: Upload User profile image to firebase storage
  Future<String> uploadUserImage(File imageFile) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      String? userName = FirebaseAuth.instance.currentUser?.displayName ?? "";
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'user_images/${userId}_$userName/$timestamp.jpeg';

      // Upload the resized image to Firebase Storage
      File resizedImageFile = await resizeImage(imageFile, 200, 200);
      await FirebaseStorage.instance.ref(fileName).putFile(resizedImageFile);

      // Get the download URL of the uploaded image
      String imageUrl = await FirebaseStorage.instance.ref(fileName).getDownloadURL();

      return imageUrl;
    } catch (e) {
      print("Error uploading image: $e");
      return "";
    }
  }

  Future<void> deleteActivityImage(String imageUrl) async {
    try {
      Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();
    } catch (e) {
      print("Error deleting image: $e");
    }
  }

  Future<void> deleteUserImage(String imageUrl) async {
    try {
      Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
      await storageRef.delete();
    } catch (e) {
      print("Error deleting image: $e");
    }
  }


  Future<File> resizeImage(File imageFile, double width, double height) async {
    // Dosyayı oku ve image paketini kullanarak image nesnesine dönüştür
    List<int> imageBytes = await imageFile.readAsBytes();
    img.Image image = img.decodeImage(Uint8List.fromList(imageBytes))!;

    // Belirli genişlik ve yüksekliğe boyutlandır
    img.Image resizedImage = img.copyResize(image, width: width.toInt(), height: height.toInt());

    // Boyutlandırılmış resmi bir File nesnesine dönüştür
    File resultFile = File(imageFile.path)
      ..writeAsBytesSync(Uint8List.fromList(img.encodePng(resizedImage)));

    return resultFile;
  }


  void checkActivityMembershipAndNavigate(BuildContext context, Activities selectedActivity) {
    // Grup üyeliğini kontrol et
    bool isMember = selectedActivity.memberIds.contains(UsersManager().currentUser!.id);

    if (isMember) {
      // Kullanıcı grup üyesiyse UsersScreen'e git
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityMembersScreen(activity: selectedActivity),
        ),
      );
    } else {
      // Kullanıcı grup üyesi değilse uyarı göster
      showMembershipAlert(context,selectedActivity.id);
    }
  }

  void showMembershipAlert(BuildContext context, String activityId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kSecondaryColor,
          title: const Text("Warning",style: TextStyle(color: kSecondaryColor2),),
          content: const Text("You are not a member of this activity. Send a request to join.",style: TextStyle(color: Colors.white),),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel",style: TextStyle(color: kSecondaryColor2),),
            ),
            TextButton(
              onPressed: () {
                sendRequestToJoinActivity(context, activityId);
                Navigator.of(context).pop();
              },
              child: const Text("Send Request",style: TextStyle(color: kSecondaryColor2),),
            ),
          ],
        );
      },
    );
  }

  // TODO: Grup üyeliği için istek gönderme işlemleri
  void sendRequestToJoinActivity(BuildContext context, String activityId) async {
    print("istek gönderme başlatıldı");
    String userId = UsersManager().currentUser!.id;
    await activityCollection.doc(activityId).update(
        {"joinRequests": FieldValue.arrayUnion([userId])},
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text("Request sent successfully.",style: TextStyle(color: kSecondaryColor),),
          backgroundColor: kSecondaryColor2,
          duration: Durations.extralong4
      ),);
    notifyActivityOwner(activityId, userId);
  }
  // TODO:Notify activity owner about join request
  void notifyActivityOwner(String activityId, String userId) {
    // notification logic here
    // Firebase Cloud Messaging (FCM) or push notification
  }
  //TODO: accept join request
  Future<void> acceptJoinRequest(Activities activity, Users user) async {
    await activityCollection.doc(activity.id).update({
      "memberIds": FieldValue.arrayUnion([user.id]),
      "joinRequests": FieldValue.arrayRemove([user.id]),
    });
  }
  //TODO: reject join request
  Future<void> rejectJoinRequest(Activities activity, Users user) async {
    await activityCollection.doc(activity.id).update({
      "joinRequests": FieldValue.arrayRemove([user.id]),
    });
  }
  //TODO: remove from activity
  Future<void> removeFromActivity(Activities activity, Users user) async {
    await activityCollection.doc(activity.id).update({
      "memberIds": FieldValue.arrayRemove([user.id]),
    });
  }
  //TODO: Cancel request to join activity
  Future<void> cancelRequest(Activities activity, Users user) async {
    await activityCollection.doc(activity.id).update({
      "joinRequests": FieldValue.arrayRemove([user.id]),
    });
  }

  //TODO: update curent user last location into firebase with timer when app is open
  Timer? _updateMyLocationTimer;
  Future<void> runUpdateMyLocation() async {
    _updateMyLocationTimer?.cancel();
    await _updateMyLocation();
     _updateMyLocationTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      await _updateMyLocation();
    });
  }
  //TODO: Update my location and speed, send to firestore method
  Future<void> _updateMyLocation() async {
    Users? currentUser = UsersManager().currentUser; // Mevcut kullanıcıyı al
    Position myLastPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    if (currentUser != null) {
      DateTime now = DateTime.now();

      // Hızı hesapla (m/s cinsinden)
      double speed = myLastPosition.speed ?? 0;
      double speedInKmPerHour = myLastPosition.speed != null ? myLastPosition.speed * 3.6 : 0;

      // Hız 0 ise ve önceki hız da 0 ise konum güncellemesini yapma
      if (speed == 0 && _lastSpeed == 0) {
        return;
      }

      // Firestore'da kullanıcının son konumunu güncelle
      await FirebaseFirestore.instance.collection('users').doc(currentUser.id).update({
        "lastLocation": {
          "latitude": myLastPosition.latitude,
          "longitude": myLastPosition.longitude,
        },
        "lastSpeed": speedInKmPerHour, // Hızı güncelle
        "lastLocationUpdatedAt": now, // Son güncelleme tarihi
      });

      // Hızı güncelle
      _lastSpeed = speed;

      print("${currentUser.name} son konumu Firestore'a gönderildi, Hız: $speedInKmPerHour m/s");
    } else {
      print("Konum güncellenemedi, çünkü kullanıcı bulunamadı");
    }
  }



}

