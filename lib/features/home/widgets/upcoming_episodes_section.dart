import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../bloc/graphql_client/graphql_client_cubit.dart';
import '../../../bloc/paginated_data/paginated_data_bloc.dart';
import '../../../bloc/upcoming_episodes/upcoming_episodes_bloc.dart';
import '../../../core/ui/error_text.dart';
import '../../../core/ui/media_section/scroll_to_left_button.dart';
import '../../../core/ui/shimmers/shimmer_loader_list.dart';
import '../../../generated/assets.dart';
import '../../../graphql/__generated/graphql/home/upcoming_episodes.graphql.dart';
import '../../../services/caching/image_cache_manager.dart';
import '../../../theme/colors.dart';
import '../../../utils/formatting_utils.dart';
import '../../../utils/ui_utils.dart';

class UpcomingEpisodesSection extends HookWidget {
  const UpcomingEpisodesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final controller = useScrollController();

    useEffect(() {
      controller.addListener(() {
        final maxScroll = controller.position.maxScrollExtent;
        final currentScroll = controller.position.pixels;

        if (currentScroll == maxScroll) {
          dev.log('Max scrolled', name: 'UpcomingEpisodes');
          final upcomingEpisodesBloc = context.read<UpcomingEpisodesBloc>();
          final hasNextPage =
              (upcomingEpisodesBloc.state as PaginatedDataLoaded).hasNextPage;
          if (hasNextPage) {
            final client = (context.read<GraphqlClientCubit>().state
                    as GraphqlClientInitialized)
                .client;
            upcomingEpisodesBloc.add(LoadData(client));
          }
        }
      });
      return null;
    });

    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: BlocBuilder<UpcomingEpisodesBloc, PaginatedDataState>(
        builder: (context, state) {
          if (state is PaginatedDataLoading || state is PaginatedDataInitial) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Episodes',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontFamily: 'Roboto-Condensed',
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 10),
                ShimmerLoaderList(
                  direction: Axis.horizontal,
                  height: UIUtils.getWidgetHeight(
                    targetWidgetHeight: 134,
                    screenHeight: screenHeight,
                  ),
                  widgetBorder: 15,
                  widgetHeight: UIUtils.getWidgetHeight(
                    targetWidgetHeight: 134,
                    screenHeight: screenHeight,
                  ),
                  widgetWidth: UIUtils.getWidgetWidth(
                    targetWidgetWidth: 215,
                    screenWidth: screenWidth,
                  ),
                ),
              ],
            );
          } else if (state is PaginatedDataLoaded) {
            dev.log('Rebuilding the episodes list');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upcoming Episodes',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontFamily: 'Roboto-Condensed',
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 10),
                _buildUpcomingEpisodesList(
                  state.list as List<Query$GetUpcomingEpisodes$Page$media?>,
                  state.hasNextPage,
                  screenHeight,
                  controller,
                ),
              ],
            );
          } else if (state is PaginatedDataError) {
            return ErrorText(
                message: state.message,
                onTryAgain: () {
                  final client = (context.read<GraphqlClientCubit>().state
                          as GraphqlClientInitialized)
                      .client;
                  context.read<UpcomingEpisodesBloc>().add(LoadData(client));
                });
          } else {
            return const Text('Unknown State');
          }
        },
      ),
    );
  }

  Widget _buildUpcomingEpisodesList(
    List<Query$GetUpcomingEpisodes$Page$media?> episodes,
    bool hasNextPage,
    double screenHeight,
    ScrollController controller,
  ) {
    final List<Color> cardColors = [
      AppColors.sunsetOrange,
      AppColors.crayola,
      AppColors.kiwi,
    ];

    return SizedBox(
      height: UIUtils.getWidgetHeight(
        targetWidgetHeight: 134,
        screenHeight: screenHeight,
      ),
      child: Stack(
        children: [
          CustomScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            controller: controller,
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildUpcomingEpisodeCard(
                      context: context,
                      media: episodes[index],
                      color: cardColors[index % cardColors.length],
                    );
                  },
                  childCount: episodes.length,
                ),
              ),
              if (hasNextPage)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(5.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
            ],
          ),
          ScrollToLeftFAB(controller: controller),
        ],
      ),
    );
  }

  Widget _buildUpcomingEpisodeCard({
    required BuildContext context,
    required Query$GetUpcomingEpisodes$Page$media? media,
    required Color color,
  }) {
    if (media == null) return const SizedBox();

    try {
      return Container(
        width: 215,
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.only(
          left: 8,
          bottom: 8,
        ),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, AppColors.japaneseIndigo],
          ),
          shadows: [
            BoxShadow(
              color: AppColors.black.withOpacity(0.25),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 106,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      media.title!.english ??
                          media.title!.romaji ??
                          media.title!.native!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontFamily: 'Roboto-Medium',
                          ),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Ep. ${media.airingSchedule!.nodes![0]!.episode} in'
                    '\n${FormattingUtils.formatDurationFromSeconds(media.airingSchedule!.nodes![0]!.timeUntilAiring)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          color: AppColors.lightSilver,
                        ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Anime Poster
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 5),
              child: media.coverImage?.large == null
                  ? _buildPlaceholderImage85x120()
                  : CachedNetworkImage(
                      cacheManager: ImageCacheManager.instance,
                      imageUrl: media.coverImage!.large!,
                      width: 85,
                      height: 120,
                      imageBuilder: (context, imageProvider) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                      placeholder: (context, url) =>
                          _buildPlaceholderImage85x120(),
                      errorWidget: (context, url, error) =>
                          _buildPlaceholderImage85x120(),
                    ),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox();
    }
  }

  Widget _buildPlaceholderImage85x120() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Image.asset(Assets.placeholders85x120),
    );
  }
}
