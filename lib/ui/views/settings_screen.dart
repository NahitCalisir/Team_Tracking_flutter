import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:team_tracking/data/entity/users.dart';
import 'package:team_tracking/ui/cubits/settings_secreen_cubit.dart';
import 'package:team_tracking/utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  Users currentUser;
  SettingsScreen({super.key,required this.currentUser});


  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    context.read<SettingsScreenCubit>().resetImage();
    _nameController.text = widget.currentUser.name ?? "";
    _phoneController.text = widget.currentUser.phone ?? "";
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsScreenCubit, File?>(
      builder: (context, userImageFile){
        return Scaffold(
          appBar: AppBar(
            title: const Text("Profile"),
          ),
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    GestureDetector(
                        onTap: (){
                          context.read<SettingsScreenCubit>().pickImage();
                        } ,
                        child: userImageFile == null ?
                        widget.currentUser.photoUrl == "" ?
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const Icon(
                            Icons.add_a_photo,
                            color: kSecondaryColor2, // İkonun rengini belirleyin
                            size: 150, // İkonun boyutunu belirleyin
                          ),
                        ):
                        ClipOval(
                          child: Image(
                            image: NetworkImage(widget.currentUser.photoUrl!),
                            fit: BoxFit.cover,
                            width: 150,
                            height: 150,
                          ),
                        )
                            : ClipOval(
                            child: Image(
                              image: FileImage(userImageFile),
                              fit: BoxFit.cover,
                              height: 198,
                              width: 198,
                            )
                        )
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Name*"),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: "Phone Number"),
                    ),
                    const SizedBox(height: 50),
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: kSecondaryColor2,
                                foregroundColor: Colors.white),
                            onPressed: () async {
                              await context.read<SettingsScreenCubit>().editUser(
                                  context: context,
                                  userId: widget.currentUser.id,
                                  name: _nameController.text.trim(),
                                  phone: _phoneController.text.trim(),
                                  userImage: userImageFile,
                                  photoUrl: widget.currentUser.photoUrl,
                              );
                            },
                            child: const Text("Save",style: TextStyle(fontSize: 20),)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            //style: ElevatedButton.styleFrom(backgroundColor: kSecondaryColor2,foregroundColor: Colors.white),
                            onPressed: (){
                              context.read<SettingsScreenCubit>().signOut(context);
                            },
                            child: const Text("Sign Out",style: TextStyle(fontSize: 20,color: Colors.red)))
                      ],
                    ),

                  ],
                ),
              ),
            )
        );
      },
    );
  }
}

/*
          body: Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      currentUser.photoUrl != null && currentUser.photoUrl!.isNotEmpty ?
                      ClipOval(
                        child: Image(
                          image: NetworkImage(currentUser.photoUrl!,),
                          width: 100,
                          height: 100,
                        ),
                      ):
                      const Icon(Icons.account_circle, size: 200, color: kSecondaryColor2),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(currentUser.name,style: const TextStyle(fontSize: 17,fontWeight: FontWeight.bold),),
                            Text(currentUser.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: kSecondaryColor2,foregroundColor: Colors.white),
                      onPressed: (){
                        context.read<SettingsScreenCubit>().signOut(context);
                      },
                      child: const Text("SIGN OUT"))
                ],
              )
          ),
 */