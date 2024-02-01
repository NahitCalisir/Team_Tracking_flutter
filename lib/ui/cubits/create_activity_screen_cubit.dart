import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:team_tracking/data/repo/activity_tracking_dao_repository.dart';

class CreateActivityScreenCubit extends Cubit<File?> {
  CreateActivityScreenCubit(): super(null);

  Future<void> saveActivity(
      {
        required BuildContext context,
        required String name,
        required String city,
        required String country,
        required File? activityImage
      }) async {
    ActivityTrackingDaoRepository.shared.createActivity(
      context: context,
      name: name,
      city: city,
      country: country,
      activityImage: activityImage,
    );
  }

  Future<void> pickImage() async {
    File? activityImageFile;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);


    if(image != null) {
      activityImageFile = File(image.path);
      File resizedImage = await ActivityTrackingDaoRepository.shared.resizeImage(activityImageFile, 300, 300);
      emit(resizedImage);
    }
  }
  Future<void> resetImage() async {
    emit(null);
  }

}