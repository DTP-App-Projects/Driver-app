part of 'content_cubit.dart';

sealed class ContentState {}

final class ContentInitial extends ContentState {}

final class ContentLoadingState extends ContentState {}

final class ContentPageSuccessState extends ContentState {
  final ContentPageModel page;

  ContentPageSuccessState({required this.page});
}

final class ContentSupportSuccessState extends ContentState {
  final List<SupportChannelModel> channels;

  ContentSupportSuccessState({required this.channels});
}

final class ContentErrorState extends ContentState {
  final String errMessage;

  ContentErrorState({required this.errMessage});
}
