import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sdal/features/profile/data/profile_repository.dart';

void main() {
  test('ProfileData decodes legacy field aliases', () {
    final profile = ProfileData.fromMap({
      'id': 1,
      'kadi': 'uye',
      'isim': 'Ada',
      'soyisim': 'Lovelace',
      'email': 'ada@example.com',
      'mezuniyetyili': '2011',
      'sehir': 'Istanbul',
      'meslek': 'Engineer',
      'websitesi': 'https://example.com',
      'universite': 'SDAL',
      'imza': 'signature',
      'resim': '/uploads/photo.jpg',
      'sirket': 'OpenAI',
      'unvan': 'Member',
      'uzmanlik': 'AI',
      'linkedin_url': 'https://linkedin.com/in/ada',
      'universite_bolum': 'CS',
      'mentor_opt_in': 1,
      'mentor_konulari': 'Career',
      'kvkk_consent': true,
      'directory_consent': '1',
      'mailkapali': 0,
    });

    expect(profile.username, 'uye');
    expect(profile.firstName, 'Ada');
    expect(profile.photo, '/uploads/photo.jpg');
    expect(profile.mentorOptIn, isTrue);
    expect(profile.emailHidden, isFalse);
  });

  test('VerificationUploadResult decodes proof aliases', () {
    final upload = VerificationUploadResult.fromMap({
      'proof_path': '/uploads/proof.jpg',
      'proof_image_record_id': 'img_42',
    });

    expect(upload.proofPath, '/uploads/proof.jpg');
    expect(upload.proofImageRecordId, 'img_42');
  });
}
