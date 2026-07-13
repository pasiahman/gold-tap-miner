import 'dart:async';
import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService({required this.enabled});

  final bool enabled;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  static const _androidBannerTest = 'ca-app-pub-3940256099942544/6300978111';
  static const _androidRewardedTest = 'ca-app-pub-3940256099942544/5224354917';
  static const _androidInterstitialTest = 'ca-app-pub-3940256099942544/1033173712';
  static const _iosBannerTest = 'ca-app-pub-3940256099942544/2934735716';

  String get bannerUnitId => Platform.isAndroid ? _androidBannerTest : _iosBannerTest;

  Future<void> initialize() async {
    if (!enabled) return;
    await MobileAds.instance.initialize();
    loadRewarded();
    loadInterstitial();
  }

  BannerAd createBanner() => BannerAd(
        adUnitId: bannerUnitId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: const BannerAdListener(),
      );

  void loadRewarded() {
    if (!enabled) return;
    RewardedAd.load(
      adUnitId: _androidRewardedTest,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  Future<bool> showRewarded() async {
    if (!enabled) return true;
    final ad = _rewardedAd;
    if (ad == null) {
      loadRewarded();
      return false;
    }
    final result = Completer<bool>();
    _rewardedAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadRewarded();
        if (!result.isCompleted) result.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadRewarded();
        if (!result.isCompleted) result.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, __) {
      if (!result.isCompleted) result.complete(true);
    });
    return result.future;
  }

  void loadInterstitial() {
    if (!enabled) return;
    InterstitialAd.load(
      adUnitId: _androidInterstitialTest,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  void showInterstitialAtNaturalBreak() {
    if (!enabled) return;
    final ad = _interstitialAd;
    if (ad == null) return;
    _interstitialAd = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        loadInterstitial();
      },
    );
    ad.show();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
