import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

class ProfileController {
  const ProfileController._();

  static final ValueNotifier<UserProfile> profile = ValueNotifier<UserProfile>(
    const UserProfile(
      name: 'Kelompok 2',
      email: 'kelompok2@farm.com',
      phone: '0812-3456-7890',
      farmName: 'Kandang SIPPA 01',
      location: 'Bandung, Jawa Barat',
    ),
  );
}
  