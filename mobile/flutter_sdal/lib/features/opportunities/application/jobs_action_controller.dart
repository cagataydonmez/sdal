import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/async_action_state.dart';
import '../../feed/data/feed_repository.dart';
import '../data/opportunities_repository.dart';

class JobsActionController extends Notifier<AsyncActionState> {
  OpportunitiesRepository get _repository =>
      ref.read(opportunitiesRepositoryProvider);

  @override
  AsyncActionState build() => const AsyncActionState.idle();

  Future<bool> createJob({
    required String company,
    required String title,
    required String description,
    required String location,
    required String jobType,
    required String workMode,
    required String link,
    File? imageFile,
    bool showInFeed = true,
    bool publish = true,
  }) async {
    state = const AsyncActionState.loading(scope: 'jobs:create');
    final result = await _repository.createJob(
      company: company,
      title: title,
      description: description,
      location: location,
      jobType: jobType,
      workMode: workMode,
      link: link,
      imageFile: imageFile,
      showInFeed: showInFeed,
      publish: publish,
    );
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      ref.invalidate(feedItemsProvider);
      state = const AsyncActionState.success(scope: 'jobs:create');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'jobs:create',
      message: result.message.isNotEmpty
          ? result.message
          : 'İş ilanı oluşturulamadı.',
    );
    return false;
  }

  Future<bool> editJob({
    required int jobId,
    required String title,
    required String company,
    required String description,
    required String location,
    required String jobType,
    required String workMode,
    required String link,
  }) async {
    state = AsyncActionState.loading(scope: 'jobs:edit:$jobId');
    final result = await _repository.editJob(
      jobId: jobId,
      title: title,
      company: company,
      description: description,
      location: location,
      jobType: jobType,
      workMode: workMode,
      link: link,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'jobs:edit');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'jobs:edit:$jobId',
      message: result.message.isNotEmpty
          ? result.message
          : 'İlan düzenlenemedi.',
    );
    return false;
  }

  Future<bool> deleteJob(int jobId) async {
    state = AsyncActionState.loading(scope: 'jobs:delete:$jobId');
    final result = await _repository.deleteJob(jobId);
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'jobs:delete');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'jobs:delete:$jobId',
      message: result.message.isNotEmpty ? result.message : 'İlan silinemedi.',
    );
    return false;
  }

  Future<bool> setJobPublished({
    required int jobId,
    required bool publish,
  }) async {
    state = AsyncActionState.loading(scope: 'jobs:publish:$jobId');
    final result = await _repository.setJobPublished(
      jobId: jobId,
      publish: publish,
    );
    if (result.ok) {
      ref.invalidate(feedPageProvider);
      ref.invalidate(feedItemsProvider);
      state = AsyncActionState.success(
        scope: 'jobs:publish:$jobId',
        message: publish
            ? 'İş ilanı yayına alındı.'
            : 'İş ilanı taslaklara alındı.',
      );
      return true;
    }
    state = AsyncActionState.error(
      scope: 'jobs:publish:$jobId',
      message: result.message.isNotEmpty
          ? result.message
          : 'İş ilanı durumu güncellenemedi.',
    );
    return false;
  }

  Future<bool> apply({
    required int jobId,
    String coverLetter = '',
    String cvLink = '',
    String contactChannel = '',
    String contactValue = '',
    String city = '',
  }) async {
    state = AsyncActionState.loading(scope: 'jobs:apply:$jobId');
    final result = await _repository.applyToJob(
      jobId: jobId,
      coverLetter: coverLetter,
      cvLink: cvLink,
      contactChannel: contactChannel,
      contactValue: contactValue,
      city: city,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'jobs:apply');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'jobs:apply:$jobId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Başvuru gönderilemedi.',
    );
    return false;
  }

  Future<bool> review({
    required int jobId,
    required int applicationId,
    required String status,
    required String decisionNote,
  }) async {
    state = AsyncActionState.loading(
      scope: 'jobs:review:$jobId:$applicationId',
    );
    final result = await _repository.reviewApplication(
      jobId: jobId,
      applicationId: applicationId,
      status: status,
      decisionNote: decisionNote,
    );
    if (result.ok) {
      state = const AsyncActionState.success(scope: 'jobs:review');
      return true;
    }
    state = AsyncActionState.error(
      scope: 'jobs:review:$jobId:$applicationId',
      message: result.message.isNotEmpty
          ? result.message
          : 'Başvuru güncellenemedi.',
    );
    return false;
  }
}

final jobsActionControllerProvider =
    NotifierProvider.autoDispose<JobsActionController, AsyncActionState>(
      JobsActionController.new,
    );
