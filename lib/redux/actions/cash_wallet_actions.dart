import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_segment/flutter_segment.dart';
import 'package:fusecash/models/community/business.dart';
import 'package:fusecash/models/cash_wallet_state.dart';
import 'package:fusecash/models/community/community.dart';
import 'package:fusecash/models/community/community_metadata.dart';
import 'package:fusecash/models/jobs/base.dart';
import 'package:fusecash/models/plugins/plugins.dart';
import 'package:fusecash/models/tokens/token.dart';
import 'package:fusecash/models/transactions/transaction.dart';
import 'package:fusecash/models/transactions/transfer.dart';
import 'package:fusecash/models/user_state.dart';
import 'package:fusecash/redux/actions/error_actions.dart';
import 'package:flutter_branch_sdk/flutter_branch_sdk.dart';
import 'package:fusecash/redux/actions/pro_mode_wallet_actions.dart';
import 'package:fusecash/redux/actions/user_actions.dart';
import 'package:fusecash/utils/addresses.dart';
import 'package:fusecash/redux/state/store.dart';
import 'package:fusecash/utils/constans.dart';
import 'package:fusecash/utils/firebase.dart';
import 'package:fusecash/utils/format.dart';
import 'package:http/http.dart';
import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:wallet_core/wallet_core.dart' as wallet_core;
import 'package:fusecash/services.dart';
import 'dart:async';
import 'dart:convert';

class SetDefaultCommunity {
  String defaultCommunity;
  SetDefaultCommunity(this.defaultCommunity);
}

class InitWeb3Success {
  final wallet_core.Web3 web3;
  InitWeb3Success(this.web3);
}

class GetWalletAddressesSuccess {
  final List<String> networks;
  final String walletAddress;
  final bool backup;
  final String communityManagerAddress;
  final String transferManagerAddress;
  final String daiPointsManagerAddress;
  GetWalletAddressesSuccess(
      {this.backup,
      this.networks,
      this.daiPointsManagerAddress,
      this.walletAddress,
      this.communityManagerAddress,
      this.transferManagerAddress});
}

class GetTokenBalanceSuccess {
  final String communityAddress;
  final BigInt tokenBalance;
  GetTokenBalanceSuccess({this.tokenBalance, this.communityAddress});
}

class AlreadyJoinedCommunity {
  final String communityAddress;
  AlreadyJoinedCommunity(this.communityAddress);
}

class JoinCommunity {
  final Map community;
  JoinCommunity({this.community});
}

class SwitchCommunityRequested {
  final String communityAddress;
  SwitchCommunityRequested(this.communityAddress);
}

class SwitchToNewCommunity {
  final String communityAddress;
  SwitchToNewCommunity(this.communityAddress);
}

class SwitchCommunitySuccess {
  final bool isClosed;
  final Token token;
  final String communityAddress;
  final String communityName;
  final Plugins plugins;
  final String homeBridgeAddress;
  final String foreignBridgeAddress;
  final String webUrl;
  final CommunityMetadata metadata;
  SwitchCommunitySuccess(
      {this.communityAddress,
      this.communityName,
      this.token,
      this.plugins,
      this.isClosed,
      this.homeBridgeAddress,
      this.foreignBridgeAddress,
      this.metadata,
      this.webUrl});
}

class FetchCommunityMetadataSuccess {
  final String communityAddress;
  final CommunityMetadata metadata;
  FetchCommunityMetadataSuccess({this.communityAddress, this.metadata});
}

class SwitchCommunityFailed {}

class StartFetchingBusinessList {
  StartFetchingBusinessList();
}

class FetchingBusinessListSuccess {
  FetchingBusinessListSuccess();
}

class FetchingBusinessListFailed {
  FetchingBusinessListFailed();
}

class GetBusinessListSuccess {
  final String communityAddress;
  final List<Business> businessList;
  GetBusinessListSuccess({this.businessList, this.communityAddress});
}

class GetTokenTransfersListSuccess {
  final String communityAddress;
  final List<Transfer> tokenTransfers;
  GetTokenTransfersListSuccess({this.communityAddress, this.tokenTransfers});
}

class StartBalanceFetchingSuccess {
  StartBalanceFetchingSuccess();
}

class SetIsTransfersFetching {
  final bool isFetching;
  SetIsTransfersFetching({this.isFetching});
}

class BranchCommunityUpdate {
  BranchCommunityUpdate();
}

class BranchCommunityToUpdate {
  final String communityAddress;
  BranchCommunityToUpdate(this.communityAddress);
}

class BranchListening {}

class BranchListeningStopped {}

class BranchDataReceived {}

class InviteSendSuccess {
  final String communityAddress;
  final Transaction invite;
  InviteSendSuccess({this.invite, this.communityAddress});
}

class ReplaceTransaction {
  final String communityAddress;
  final Transaction transaction;
  final Transaction transactionToReplace;
  ReplaceTransaction(
      {this.transaction, this.transactionToReplace, this.communityAddress});
}

class AddTransaction {
  final String communityAddress;
  final Transaction transaction;
  AddTransaction({this.transaction, this.communityAddress});
}

class AddJob {
  final String communityAddress;
  final Job job;
  AddJob({this.job, this.communityAddress});
}

class JobDone {
  final String communityAddress;
  final Job job;
  JobDone({this.job, this.communityAddress});
}

class SetIsJobProcessing {
  final bool isFetching;
  SetIsJobProcessing({this.isFetching});
}

Future<bool> approvalCallback() async {
  return true;
}

ThunkAction enablePushNotifications() {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      FirebaseMessaging firebaseMessaging = new FirebaseMessaging();
      void iosPermission() {
        var firebaseMessaging2 = firebaseMessaging;
        firebaseMessaging2.requestNotificationPermissions(
            IosNotificationSettings(sound: true, badge: true, alert: true));
        firebaseMessaging.onIosSettingsRegistered
            .listen((IosNotificationSettings settings) {
          logger.info("Settings registered: $settings");
        });
      }

      if (Platform.isIOS) iosPermission();
      String token = await firebaseMessaging.getToken();
      logger.info("Firebase messaging token $token");

      String walletAddress = store.state.userState.walletAddress;
      await api.updateFirebaseToken(walletAddress, token);
      await Segment.setContext({
        'device': {'token': token},
      });

      void switchOnPush(message) {
        String communityAddress = communityAddressFromNotification(message);
        if (communityAddress != null && communityAddress.isNotEmpty) {
          store.dispatch(switchCommunityCall(communityAddress));
        }
      }

      firebaseMessaging.configure(
        onMessage: (Map<String, dynamic> message) async {
          switchOnPush(message);
        },
        onResume: (Map<String, dynamic> message) async {
          switchOnPush(message);
        },
        onLaunch: (Map<String, dynamic> message) async {
          switchOnPush(message);
        },
      );
    } catch (e) {
      logger.severe('ERROR - Enable push notifications: $e');
    }
  };
}

ThunkAction segmentTrackCall(eventName, {Map<String, dynamic> properties}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      logger.info('Track - $eventName');
      Segment.track(eventName: eventName, properties: properties);
    } catch (e, s) {
      logger.severe('ERROR - segment track call: $e');
      await AppFactory().reportError(e, s);
    }
  };
}

ThunkAction segmentAliasCall(String userId) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      logger.info('Alias - $userId');
      Segment.alias(alias: userId);
    } catch (e, s) {
      logger.severe('ERROR - segment alias call: $e');
      await AppFactory().reportError(e, s);
    }
  };
}

ThunkAction segmentIdentifyCall(Map<String, dynamic> traits) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      UserState userState = store.state.userState;
      String fullPhoneNumber =
          store.state.userState.normalizedPhoneNumber ?? '';
      logger.info('Identify - $fullPhoneNumber');
      traits = traits ?? new Map<String, dynamic>();
      DateTime installedAt = userState.installedAt;
      if (installedAt == null) {
        installedAt = DateTime.now().toUtc();
        store.dispatch(new JustInstalled(installedAt));
      }
      traits["Installed At"] = installedAt.toIso8601String();
      traits["Display Balance"] = userState.displayBalance ?? 0;
      Segment.identify(userId: fullPhoneNumber, traits: traits);
    } catch (e, s) {
      logger.severe('ERROR - segment identify call: $e');
      await AppFactory().reportError(e, s);
    }
  };
}

ThunkAction listenToBranchCall() {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    logger.info("branch listening.");
    store.dispatch(BranchListening());

    Function handler = (linkData) async {
      logger.info("Got link data: ${linkData.toString()}");
      if (linkData["~feature"] == "switch_community") {
        var communityAddress = linkData["community_address"];
        logger.info("communityAddress $communityAddress");
        store.dispatch(BranchCommunityToUpdate(communityAddress));
        store.dispatch(segmentIdentifyCall(Map<String, dynamic>.from({
          'Referral': linkData["~feature"],
          'Referral link': linkData['~referring_link']
        })));
        store.dispatch(segmentTrackCall("Wallet: Branch: Studio Invite",
            properties: new Map<String, dynamic>.from(linkData)));
      }
      if (linkData["~feature"] == "invite_user") {
        var communityAddress = linkData["community_address"];
        logger.info("community_address $communityAddress");
        store.dispatch(BranchCommunityToUpdate(communityAddress));
        store.dispatch(segmentIdentifyCall(Map<String, dynamic>.from({
          'Referral': linkData["~feature"],
          'Referral link': linkData['~referring_link']
        })));
        store.dispatch(segmentTrackCall("Wallet: Branch: User Invite",
            properties: new Map<String, dynamic>.from(linkData)));
      }
      store.dispatch(BranchDataReceived());
    };

    FlutterBranchSdk.initSession().listen((data) {
      handler(data);
    }, onError: (error, s) async {
      logger.severe('ERROR - FlutterBranchSdk initSession $error');
      store.dispatch(BranchListeningStopped());
    }, cancelOnError: true);
  };
}

ThunkAction initWeb3Call(
  String privateKey, {
  String communityManagerAddress,
  String transferManagerAddress,
  String dAIPointsManagerAddress,
}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      logger.info('initWeb3. privateKey: $privateKey');
      logger.info('mnemonic : ${store.state.userState.mnemonic.toString()}');
      wallet_core.Web3 web3 = new wallet_core.Web3(approvalCallback,
          defaultCommunityAddress: defaultCommunityAddress,
          communityManagerAddress: communityManagerAddress ??
              DotEnv().env['COMMUNITY_MANAGER_CONTRACT_ADDRESS'],
          transferManagerAddress: transferManagerAddress ??
              DotEnv().env['TRANSFER_MANAGER_CONTRACT_ADDRESS'],
          daiPointsManagerAddress: dAIPointsManagerAddress ??
              DotEnv().env['DAI_POINTS_MANAGER_CONTRACT_ADDRESS']);
      if (store.state.cashWalletState.communityAddress == null ||
          store.state.cashWalletState.communityAddress.isEmpty) {
        store.dispatch(
            SetDefaultCommunity(web3.getDefaultCommunity().toLowerCase()));
      }
      web3.setCredentials(privateKey);
      store.dispatch(new InitWeb3Success(web3));
    } catch (e) {
      logger.severe('ERROR - initWeb3Call $e');
      store.dispatch(new ErrorAction('Could not init web3'));
    }
  };
}

ThunkAction startTransfersFetchingCall() {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    bool isTransfersFetchingStarted =
        store.state.cashWalletState.isTransfersFetchingStarted ?? false;
    Map<String, Community> communities =
        store.state.cashWalletState.communities;
    final String walletAddress = store.state.userState.walletAddress;
    if (!isTransfersFetchingStarted &&
        communities.isNotEmpty &&
        walletAddress != null) {
      try {
        Map<String, Community> communities =
            store.state.cashWalletState.communities;
        for (Community community in communities.values) {
          if (community.token.address != null) {
            store.dispatch(getTokenTransfersListCall(community));
            store.dispatch(getTokenBalanceCall(community));
          }
        }
        logger.info('Timer start - startTransfersFetchingCall');
        new Timer.periodic(Duration(seconds: intervalSeconds), (Timer t) async {
          if (store.state.userState.walletAddress == '') {
            logger.info('Timer stopeed - startTransfersFetchingCall');
            t.cancel();
            store.dispatch(new SetIsTransfersFetching(isFetching: false));
            return;
          }
          Map<String, Community> communities =
              store.state.cashWalletState.communities;
          for (Community community in communities.values) {
            if (community.token.address != null) {
              store.dispatch(getReceivedTokenTransfersListCall(community));
            }
          }
        });
        store.dispatch(new SetIsTransfersFetching(isFetching: true));
      } catch (e) {
        logger.severe('error in startTransfersFetchingCall $e');
      }
    }
  };
}

ThunkAction createAccountWalletCall(String accountAddress) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      Map<String, dynamic> response = await api.createWallet();
      if (!response.containsKey('job')) {
        logger.info('Wallet already exists');
        store.dispatch(new CreateAccountWalletSuccess(accountAddress));
        store.dispatch(generateWalletSuccessCall(response, accountAddress));
        return;
      }
      wallet_core.Web3 web3 = store.state.cashWalletState.web3;
      if (web3 == null) {
        throw "Web3 is empty";
      }
      final String communityAddress = web3.getDefaultCommunity().toLowerCase();
      CashWalletState cashWalletState = store.state.cashWalletState;
      List<Job> jobs =
          cashWalletState.communities[communityAddress]?.token?.jobs ?? [];
      bool hasCreateWallet = jobs.any((job) => job.jobType == 'createWallet');
      if (hasCreateWallet) {
        store.dispatch(new CreateAccountWalletRequest(accountAddress));
        return;
      }
      response['job']['arguments'] = {
        'accountAddress': accountAddress,
        'communityAddress': communityAddress
      };
      Job job = JobFactory.create(response['job']);
      logger.info(
          'createAccountWalletCall for accountAddress: $accountAddress ${job.id}');
      store.dispatch(AddJob(job: job, communityAddress: communityAddress));
      store.dispatch(new CreateAccountWalletRequest(accountAddress));
    } catch (e) {
      logger.severe('ERROR - createAccountWalletCall $e');
      store.dispatch(new ErrorAction('Could not create wallet'));
    }
  };
}

ThunkAction generateWalletSuccessCall(
    dynamic walletData, String accountAddress) {
  return (Store store) async {
    String walletAddress = walletData["walletAddress"];
    if (walletAddress != null && walletAddress.isNotEmpty) {
      store.dispatch(enablePushNotifications());
      String privateKey = store.state.userState.privateKey;
      List<String> networks = List<String>.from(walletData['networks']);
      String communityManager = walletData['communityManager'];
      String transferManager = walletData['transferManager'];
      String dAIPointsManager = walletData['dAIPointsManager'];
      store.dispatch(initWeb3Call(privateKey,
          communityManagerAddress: communityManager,
          transferManagerAddress: transferManager,
          dAIPointsManagerAddress: dAIPointsManager));
      bool deployedToForeign = networks?.contains(foreignNetwork) ?? false;
      if (deployedToForeign) {
        store.dispatch(initWeb3ProMode(
            privateKey: privateKey,
            communityManagerAddress: communityManager,
            transferManagerAddress: transferManager,
            dAIPointsManagerAddress: dAIPointsManager));
      }
      store.dispatch(new GetWalletAddressesSuccess(
          walletAddress: walletAddress,
          daiPointsManagerAddress: dAIPointsManager,
          communityManagerAddress: communityManager,
          transferManagerAddress: transferManager,
          networks: networks));
      store.dispatch(segmentIdentifyCall(new Map<String, dynamic>.from({
        "Wallet Generated": true,
        "App name": 'Fuse',
        "Phone Number": store.state.userState.normalizedPhoneNumber,
        "Wallet Address": store.state.userState.walletAddress,
        "Account Address": store.state.userState.accountAddress,
        "Display Name": store.state.userState.displayName
      })));
      store.dispatch(segmentTrackCall('Wallet: Wallet Generated'));
      store.dispatch(create3boxAccountCall(accountAddress));
    }
  };
}

ThunkAction getWalletAddressessCall() {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      String privateKey = store.state.userState.privateKey;
      dynamic walletData = await api.getWallet();
      List<String> networks = List<String>.from(walletData['networks']);
      String walletAddress = walletData['walletAddress'];
      bool backup = walletData['backup'];
      String communityManagerAddress = walletData['communityManager'];
      String transferManagerAddress = walletData['transferManager'];
      String dAIPointsManagerAddress = walletData['dAIPointsManager'];
      store.dispatch(GetWalletAddressesSuccess(
          backup: backup,
          walletAddress: walletAddress,
          daiPointsManagerAddress: dAIPointsManagerAddress,
          communityManagerAddress: communityManagerAddress,
          transferManagerAddress: transferManagerAddress,
          networks: networks));
      if (networks.contains(foreignNetwork)) {
        store.dispatch(initWeb3ProMode(
            privateKey: privateKey,
            communityManagerAddress: communityManagerAddress,
            transferManagerAddress: transferManagerAddress,
            dAIPointsManagerAddress: dAIPointsManagerAddress));
      }
      store.dispatch(initWeb3Call(privateKey,
          communityManagerAddress: communityManagerAddress,
          transferManagerAddress: transferManagerAddress,
          dAIPointsManagerAddress: dAIPointsManagerAddress));
    } catch (e) {
      logger.severe('ERROR - getWalletAddressCall $e');
      store.dispatch(new ErrorAction('Could not get wallet address'));
    }
  };
}

ThunkAction getTokenBalanceCall(Community community) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      String walletAddress = store.state.userState.walletAddress;
      void Function(BigInt) onDone = (BigInt balance) {
        logger.info('${community.token.name} balance updated');
        store.dispatch(GetTokenBalanceSuccess(
            tokenBalance: balance, communityAddress: community.address));
        store.dispatch(UpdateDisplayBalance(
            int.tryParse(formatValue(balance, community.token.decimals))));
        store.dispatch(segmentIdentifyCall(Map<String, dynamic>.from({
          '${community.name} Balance': balance,
          "DisplayBalance": balance
        })));
      };
      void Function(Object error, StackTrace stackTrace) onError =
          (Object error, StackTrace stackTrace) {
        logger.severe(
            'Error in fetchTokenBalance for - ${community.token.name} $error');
      };
      await community.token
          .fetchTokenBalance(walletAddress, onDone: onDone, onError: onError);
    } catch (e) {
      logger.severe('ERROR - getTokenBalanceCall $e');
      store.dispatch(new ErrorAction('Could not get token balance'));
    }
  };
}

ThunkAction fetchJobCall(String jobId, Function(Job) fetchSuccessCallback,
    {Timer timer, bool untilDone}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      dynamic response = await api.getJob(jobId);
      logger.info('fetchJobCall: ${response['data']}');
      Job job = JobFactory.create(response);
      logger.info("job.name: ${job.name}");
      if (untilDone) {
        if (job.lastFinishedAt == null || job.lastFinishedAt.isEmpty) {
          logger.info('job not done');
          return;
        }
      } else {
        if (job.data['txHash'] == null) {
          logger.info('fetched job with txHash null');
          return;
        }
      }
      fetchSuccessCallback(job);
      if (timer != null) {
        logger.info('Timer stopeed - fetchJobCall');
        timer.cancel();
      }
    } catch (e) {
      logger.severe('ERROR - fetchJobCall $e');
      store.dispatch(new ErrorAction('Could not get job'));
    }
  };
}

ThunkAction startFetchingJobCall(
    String jobId, Function(Job) fetchSuccessCallback,
    {bool untilDone: true}) {
  return (Store store) async {
    new Timer.periodic(Duration(seconds: intervalSeconds), (Timer timer) async {
      store.dispatch(fetchJobCall(jobId, fetchSuccessCallback,
          timer: timer, untilDone: untilDone));
    });
  };
}

ThunkAction processingJobsCall(Timer timer) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    final String walletAddress = store.state.userState.walletAddress;
    Map<String, Community> communities =
        store.state.cashWalletState.communities;
    for (Community community in communities.values) {
      for (Job job in community.token.jobs) {
        String currentWalletAddress = store.state.userState.walletAddress;
        if (job.status != 'DONE' && job.status != 'FAILED') {
          bool isJobProcessValid() {
            if (currentWalletAddress != walletAddress) {
              logger.info('Timer stopeed - processingJobsCall');
              store.dispatch(SetIsJobProcessing(isFetching: false));
              timer.cancel();
              return false;
            }
            if (job.status == 'DONE') {
              return false;
            }
            return true;
          }

          try {
            // logger.info('cash mode performing ${job.name} isJobProcessValid ${isJobProcessValid()}');
            await job.perform(store, isJobProcessValid);
          } catch (e) {
            logger.severe('failed perform ${job.name}');
          }
        }
        if (job.status == 'DONE') {
          store
              .dispatch(JobDone(job: job, communityAddress: community.address));
          String tokenAddress = community?.token?.address;
          if (tokenAddress != null) {
            store.dispatch(getTokenBalanceCall(community));
          }
        }
      }
    }
  };
}

ThunkAction startProcessingJobsCall() {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    final bool isJobProcessingStarted =
        store.state.cashWalletState.isJobProcessingStarted ?? false;
    if (!isJobProcessingStarted) {
      logger.info('Start Processing Jobs Call');
      new Timer.periodic(Duration(seconds: intervalSeconds),
          (Timer timer) async {
        store.dispatch(processingJobsCall(timer));
      });
      store.dispatch(SetIsJobProcessing(isFetching: true));
    }
  };
}

ThunkAction inviteAndSendCall(
    Token token,
    String name,
    String contactPhoneNumber,
    num tokensAmount,
    VoidCallback sendSuccessCallback,
    VoidCallback sendFailureCallback,
    {String receiverName = ''}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      String senderName = store.state.userState.displayName;
      Map<String, Community> communities =
          store.state.cashWalletState.communities;
      Community community = communities.values.firstWhere((element) =>
          element.token.address.toLowerCase() == token.address.toLowerCase());
      dynamic response = await api.invite(contactPhoneNumber,
          communityAddress: community.address,
          name: senderName,
          amount: tokensAmount.toString(),
          symbol: token.symbol);
      sendSuccessCallback();

      String tokenAddress = token?.address;

      BigInt value = toBigInt(tokensAmount, token.decimals);
      String walletAddress = store.state.userState.walletAddress;

      Transfer inviteTransfer = new Transfer(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          from: walletAddress,
          to: '',
          tokenAddress: tokenAddress,
          value: value,
          type: 'SEND',
          receiverName: receiverName,
          status: 'PENDING',
          jobId: response['job']['_id']);
      store.dispatch(AddTransaction(
          transaction: inviteTransfer, communityAddress: community.address));

      response['job']['arguments'] = {
        'tokensAmount': tokensAmount,
        'receiverName': receiverName,
        'sendSuccessCallback': () => {},
        'sendFailureCallback': sendFailureCallback,
        'inviteTransfer': inviteTransfer,
        'communityAddress': community.address
      };

      Job job = JobFactory.create(response['job']);
      store.dispatch(AddJob(job: job, communityAddress: community.address));
    } catch (e) {
      logger.severe('ERROR - inviteAndSendCall $e');
    }
  };
}

ThunkAction inviteAndSendSuccessCall(
    Job job,
    dynamic data,
    num tokensAmount,
    String receiverName,
    Transfer inviteTransfer,
    VoidCallback sendSuccessCallback,
    VoidCallback sendFailureCallback,
    String communityAddress) {
  return (Store store) async {
    Community community =
        store.state.cashWalletState.communities[communityAddress];
    VoidCallback successCallBack = () {
      sendSuccessCallback();
      if (community.plugins.inviteBonus != null &&
          community.plugins.inviteBonus.isActive &&
          data['bonusInfo'] != null) {
        store.dispatch(inviteBonusCall(data, community));
      }
      store.dispatch(segmentIdentifyCall(new Map<String, dynamic>.from({
        "Invite ${community.name}": true,
      })));
    };

    String receiverAddress = job.data["walletAddress"];
    store.dispatch(sendTokenCall(community.token, receiverAddress, tokensAmount,
        successCallBack, sendFailureCallback,
        receiverName: receiverName, inviteTransfer: inviteTransfer));
    store.dispatch(loadContacts());
  };
}

ThunkAction inviteBonusCall(dynamic data, Community community) {
  return (Store store) async {
    BigInt value = toBigInt(
        community.plugins.inviteBonus.amount, community.token.decimals);
    String walletAddress = store.state.userState.walletAddress;
    String bonusJobId = data['bonusJob']['_id'];
    Transfer inviteBonus = new Transfer(
        from: DotEnv().env['FUNDER_ADDRESS'],
        to: walletAddress,
        tokenAddress: community.token.address,
        text: 'You got a invite bonus!',
        type: 'RECEIVE',
        value: value,
        status: 'PENDING',
        jobId: bonusJobId);
    store.dispatch(AddTransaction(
        transaction: inviteBonus, communityAddress: community.address));
    Map response = new Map.from({
      'job': {
        'id': bonusJobId,
        'jobType': 'inviteBonus',
        'arguments': {
          'inviteBonus': inviteBonus,
          'communityAddress': community.address,
        }
      }
    });

    Job job = JobFactory.create(response['job']);
    store.dispatch(AddJob(job: job, communityAddress: community.address));
  };
}

ThunkAction inviteBonusSuccessCall(
    String txHash, transfer, String communityAddress) {
  return (Store store) async {
    Transfer confirmedTx = transfer.copyWith(
      status: 'CONFIRMED',
      txHash: txHash,
    );
    store.dispatch(new ReplaceTransaction(
        transaction: transfer,
        transactionToReplace: confirmedTx,
        communityAddress: communityAddress));
    store.dispatch(segmentTrackCall('Wallet: invite bonus success'));
  };
}

ThunkAction sendToHomeBridgeAddressCall() {
  return (Store store) async {};
}

ThunkAction sendTokenCall(Token token, String receiverAddress, num tokensAmount,
    VoidCallback sendSuccessCallback, VoidCallback sendFailureCallback,
    {String receiverName, String transferNote, Transfer inviteTransfer}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      wallet_core.Web3 web3 = store.state.cashWalletState.web3;
      if (web3 == null) {
        throw "Web3 is empty";
      }
      String walletAddress = store.state.userState.walletAddress;
      Map<String, Community> communities =
          store.state.cashWalletState.communities;
      Community community = communities.values.firstWhere((element) =>
          element.token.address.toLowerCase() == token.address.toLowerCase());
      String tokenAddress = token?.address;

      BigInt value;
      dynamic response;
      if (receiverAddress.toLowerCase() ==
          community.homeBridgeAddress.toLowerCase()) {
        num feeAmount = community.plugins.bridgeToForeign.calcFee(tokensAmount);
        value = toBigInt(tokensAmount + feeAmount, token.decimals);
        String feeReceiverAddress =
            community.plugins.bridgeToForeign.receiverAddress;
        logger.info(
            'Sending $tokensAmount tokens of $tokenAddress from wallet $walletAddress to $receiverAddress with fee $feeAmount');
        Map<String, dynamic> trasnferData = await web3.transferTokenOffChain(
            walletAddress, tokenAddress, receiverAddress, tokensAmount);
        Map<String, dynamic> feeTrasnferData = await web3.transferTokenOffChain(
            walletAddress, tokenAddress, feeReceiverAddress, feeAmount);
        response = await api.multiRelay([trasnferData, feeTrasnferData]);
      } else {
        value = toBigInt(tokensAmount, token.decimals);
        logger.info(
            'Sending $tokensAmount tokens of $tokenAddress from wallet $walletAddress to $receiverAddress');
        response = await api.tokenTransfer(
            web3, walletAddress, tokenAddress, receiverAddress, tokensAmount);
      }

      dynamic jobId = response['job']['_id'];
      logger.info('Job $jobId for sending token sent to the relay service');

      sendSuccessCallback();
      Transfer transfer = new Transfer(
          from: walletAddress,
          to: receiverAddress,
          tokenAddress: tokenAddress,
          value: value,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: 'SEND',
          note: transferNote,
          receiverName: receiverName,
          status: 'PENDING',
          jobId: jobId);

      if (inviteTransfer != null) {
        store.dispatch(new ReplaceTransaction(
            transaction: inviteTransfer, transactionToReplace: transfer));
      } else {
        store.dispatch(new AddTransaction(
            transaction: transfer, communityAddress: community.address));
      }

      response['job']['arguments'] = {
        'transfer': transfer,
        'jobType': 'transfer',
        'communityAddress': community.address
      };
      Job job = JobFactory.create(response['job']);
      store.dispatch(AddJob(job: job, communityAddress: community.address));
    } catch (e) {
      logger.severe('ERROR - sendTokenCall $e');
      sendFailureCallback();
      store.dispatch(new ErrorAction('Could not send token'));
    }
  };
}

ThunkAction sendTokenSuccessCall(job, transfer, communityAddress) {
  return (Store store) async {
    Transfer confirmedTx = transfer.copyWith(
      status: 'CONFIRMED',
      txHash: job.data['txHash'],
    );
    store.dispatch(new ReplaceTransaction(
        transaction: transfer,
        transactionToReplace: confirmedTx,
        communityAddress: communityAddress));
  };
}

ThunkAction transactionFailed(transfer, communityAddress) {
  return (Store store) async {
    Transfer failedTx = transfer.copyWith(status: 'FAILED');
    store.dispatch(new ReplaceTransaction(
        transaction: transfer,
        transactionToReplace: failedTx,
        communityAddress: communityAddress));
  };
}

ThunkAction joinCommunityCall({dynamic community, String tokenAddress}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      wallet_core.Web3 web3 = store.state.cashWalletState.web3;
      if (web3 == null) {
        throw "Web3 is empty";
      }
      String walletAddress = store.state.userState.walletAddress;
      bool isMember = await graph.isCommunityMember(
          walletAddress, community["entitiesList"]["address"]);
      String communityAddress = community['address'];
      if (isMember) {
        store.dispatch(AlreadyJoinedCommunity(communityAddress));
        return;
      }

      dynamic response =
          await api.joinCommunity(web3, walletAddress, communityAddress);

      dynamic jobId = response['job']['_id'];
      Transfer transfer = new Transfer(
          type: 'RECEIVE',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          text: 'Joining ' + community["name"] + ' community',
          tokenAddress: tokenAddress,
          status: 'PENDING',
          jobId: jobId);

      store.dispatch(new AddTransaction(
          transaction: transfer, communityAddress: communityAddress));

      response['job']
          ['arguments'] = {'transfer': transfer, 'community': community};
      Job job = JobFactory.create(response['job']);
      store.dispatch(AddJob(job: job, communityAddress: communityAddress));
    } catch (e) {
      logger.severe('ERROR - joinCommunityCall $e');
      store.dispatch(new ErrorAction('Could not join community'));
    }
  };
}

ThunkAction joinCommunitySuccessCall(
    Job job, dynamic fetchedData, Transfer transfer, dynamic community) {
  return (Store store) async {
    Transfer confirmedTx = transfer.copyWith(
        status: 'CONFIRMED',
        text: 'Joined ' + (community["name"]) + ' community',
        txHash: job.data['txHash']);
    store.dispatch(new AlreadyJoinedCommunity(community['address']));
    store.dispatch(new ReplaceTransaction(
        transaction: transfer,
        transactionToReplace: confirmedTx,
        communityAddress: community['address']));
    Map<String, Community> communities =
        store.state.cashWalletState.communities;
    Community communityData = communities.values.firstWhere((element) =>
        element.token.address.toLowerCase() ==
        transfer.tokenAddress.toLowerCase());
    if (communityData.plugins.joinBonus != null &&
        communityData.plugins.joinBonus.isActive) {
      BigInt value = toBigInt(
          communityData.plugins.joinBonus.amount, communityData.token.decimals);
      String joinBonusJobId = fetchedData['data']['funderJobId'];
      String joinCommunityJobId = fetchedData['_id'];
      Transfer joinBonus = new Transfer(
          from: DotEnv().env['FUNDER_ADDRESS'],
          type: 'RECEIVE',
          value: value,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          tokenAddress: transfer?.tokenAddress,
          text: 'You got a join bonus!',
          status: 'PENDING',
          jobId: joinBonusJobId ?? joinCommunityJobId);
      store.dispatch(new AddTransaction(
          transaction: joinBonus, communityAddress: community['address']));
      Map response = Map.from({
        'job': {
          'id': joinBonusJobId ?? joinCommunityJobId,
          'isFunderJob': joinBonusJobId != null,
          'jobType': 'joinBonus',
          'arguments': {
            'joinBonus': joinBonus,
            'communityAddress': community['address']
          }
        }
      });
      Job job = JobFactory.create(response['job']);
      store.dispatch(AddJob(job: job, communityAddress: community['address']));
    }
  };
}

ThunkAction joinBonusSuccessCall(txHash, transfer, communiyAddress) {
  return (Store store) async {
    Map<String, Community> communities =
        store.state.cashWalletState.communities;
    Community communityData = communities[communiyAddress];
    Transfer confirmedTx = transfer.copyWith(
      status: 'CONFIRMED',
      txHash: txHash,
    );
    store.dispatch(ReplaceTransaction(
        transaction: transfer,
        transactionToReplace: confirmedTx,
        communityAddress: communityData.address));
    store.dispatch(segmentIdentifyCall(new Map<String, dynamic>.from({
      "Join Bonus ${communityData.name} Received": true,
      "Community ${communityData.name} Joined": true,
    })));
    store.dispatch(segmentTrackCall("Wallet: user got a join bonus",
        properties: new Map<String, dynamic>.from({
          "Community Name": communityData.name,
          "Bonus amount": communityData.plugins.joinBonus.amount,
        })));
  };
}

ThunkAction fetchCommunityMetadataCall(
    String communityAddress, String communityURI) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      CommunityMetadata communityMetadata;
      if (communityURI != null) {
        String hash = communityURI.startsWith('ipfs://')
            ? communityURI.split('://').last
            : communityURI.split('/').last;
        dynamic metadata = await api.fetchMetadata(hash);
        communityMetadata = new CommunityMetadata(
            image: metadata['image'],
            coverPhoto: metadata['coverPhoto'],
            imageUri: metadata['imageUri'] ?? null,
            coverPhotoUri: metadata['coverPhotoUri'] ?? null,
            isDefaultImage: metadata['isDefault'] ?? false);
      }
      store.dispatch(FetchCommunityMetadataSuccess(
          metadata: communityMetadata, communityAddress: communityAddress));
    } catch (e, s) {
      logger.info('ERROR - fetchCommunityMetadataCall $e');
      await AppFactory().reportError(e, s);
      store.dispatch(new ErrorAction('Could not fetch community metadata'));
    }
  };
}

ThunkAction switchToNewCommunityCall(String communityAddress) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      store.dispatch(new SwitchToNewCommunity(communityAddress));
      dynamic community = await graph.getCommunityByAddress(communityAddress);
      logger.info('community fetched for $communityAddress');
      dynamic token = await graph.getTokenOfCommunity(communityAddress);
      bool isRopsten = token != null && token['originNetwork'] == 'ropsten';
      logger.info(
          'token ${token["address"]} (${token["symbol"]}) fetched for $communityAddress on ${token['originNetwork']} network');
      String walletAddress = store.state.userState.walletAddress;
      Map<String, dynamic> communityData = await api.getCommunityData(
          communityAddress,
          isRopsten: isRopsten,
          walletAddress: walletAddress);
      Plugins communityPlugins = Plugins.fromJson(communityData['plugins']);
      CommunityMetadata communityMetadata;
      if (communityData['communityURI'] != null) {
        String hash = communityData['communityURI'].startsWith('ipfs://')
            ? communityData['communityURI'].split('://').last
            : communityData['communityURI'].split('/').last;
        dynamic metadata = await api.fetchMetadata(hash);
        communityMetadata = new CommunityMetadata(
            image: metadata['image'],
            coverPhoto: metadata['coverPhoto'],
            imageUri: metadata['imageUri'] ?? null,
            coverPhotoUri: metadata['coverPhotoUri'] ?? null,
            isDefaultImage: metadata['isDefault'] ?? false);
      }
      String homeBridgeAddress = communityData['homeBridgeAddress'];
      String foreignBridgeAddress = communityData['foreignBridgeAddress'];
      String webUrl = communityData['webUrl'];
      store.dispatch(joinCommunityCall(
          community: community, tokenAddress: token["address"]));
      store.dispatch(new SwitchCommunitySuccess(
          communityAddress: communityAddress,
          communityName: community["name"],
          token: Token.initial().copyWith(
              originNetwork: token['originNetwork'],
              address: token["address"],
              name: token["name"],
              symbol: token["symbol"],
              decimals: token["decimals"]),
          plugins: communityPlugins,
          metadata: communityMetadata,
          isClosed: communityData['isClosed'],
          homeBridgeAddress: homeBridgeAddress,
          foreignBridgeAddress: foreignBridgeAddress,
          webUrl: webUrl));
      store.dispatch(segmentTrackCall("Wallet: Switch Community",
          properties: new Map<String, dynamic>.from({
            "Community Name": community["name"],
            "Community Address": communityAddress,
            "Token Address": token["address"],
            "Token Symbol": token["symbol"],
            "Origin Network": token['originNetwork']
          })));
      store.dispatch(getBusinessListCall(communityAddress: communityAddress));
    } catch (e, s) {
      logger.severe('ERROR - switchToNewCommunityCall $e');
      await AppFactory().reportError(e, s);
      store.dispatch(new ErrorAction('Could not switch community'));
      store.dispatch(new SwitchCommunityFailed());
    }
  };
}

ThunkAction switchToExisitingCommunityCall(String communityAddress) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      store.dispatch(new SwitchCommunityRequested(communityAddress));
      Community current = store
          .state.cashWalletState.communities[communityAddress.toLowerCase()];
      bool isRopsten =
          current.token != null && current.token.originNetwork == 'ropsten';
      String walletAddress = store.state.userState.walletAddress;
      Map<String, dynamic> communityData = await api.getCommunityData(
          communityAddress,
          isRopsten: isRopsten,
          walletAddress: walletAddress);
      Plugins communityPlugins = Plugins.fromJson(communityData['plugins']);
      store.dispatch(getBusinessListCall(communityAddress: communityAddress));
      String homeBridgeAddress = communityData['homeBridgeAddress'];
      String foreignBridgeAddress = communityData['foreignBridgeAddress'];
      String webUrl = communityData['webUrl'];
      CommunityMetadata communityMetadata;
      if (communityData['communityURI'] != null) {
        String hash = communityData['communityURI'].startsWith('ipfs://')
            ? communityData['communityURI'].split('://').last
            : communityData['communityURI'].split('/').last;
        dynamic metadata = await api.fetchMetadata(hash);
        communityMetadata = new CommunityMetadata(
            image: metadata['image'],
            coverPhoto: metadata['coverPhoto'],
            imageUri: metadata['imageUri'] ?? null,
            coverPhotoUri: metadata['coverPhotoUri'] ?? null,
            isDefaultImage: metadata['isDefault'] ?? false);
      }
      store.dispatch(new SwitchCommunitySuccess(
          communityAddress: communityAddress,
          communityName: current.name,
          token: current.token,
          plugins: communityPlugins,
          isClosed: current.isClosed,
          homeBridgeAddress: homeBridgeAddress,
          foreignBridgeAddress: foreignBridgeAddress,
          metadata: communityMetadata,
          webUrl: webUrl));
    } catch (e, s) {
      logger.severe('ERROR - switchToExisitingCommunityCall $e');
      await AppFactory().reportError(e, s);
      store.dispatch(new ErrorAction('Could not switch community'));
      store.dispatch(new SwitchCommunityFailed());
    }
  };
}

ThunkAction switchCommunityCall(String communityAddress) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      bool isLoading = store.state.cashWalletState.isCommunityLoading ?? false;
      if (isLoading) return;
      Community current = store
          .state.cashWalletState.communities[communityAddress.toLowerCase()];
      if (current != null && current.name != null && current.token != null) {
        store.dispatch(switchToExisitingCommunityCall(communityAddress));
      } else {
        store.dispatch(switchToNewCommunityCall(communityAddress));
      }
    } catch (e, s) {
      logger.info('ERROR - switchCommunityCall $e');
      await AppFactory().reportError(e, s);
      store.dispatch(new ErrorAction('Could not switch community'));
      store.dispatch(new SwitchCommunityFailed());
    }
  };
}

Map<String, dynamic> responseHandler(Response response) {
  switch (response.statusCode) {
    case 200:
      Map<String, dynamic> obj = json.decode(response.body);
      return obj;
      break;
    default:
      throw 'Error! status: ${response.statusCode}, reason: ${response.reasonPhrase}';
  }
}

ThunkAction getBusinessListCall({String communityAddress}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      if (communityAddress == null) {
        communityAddress = store.state.cashWalletState.communityAddress;
      }
      store.dispatch(StartFetchingBusinessList());
      Community community =
          store.state.cashWalletState.communities[communityAddress];
      bool isOriginRopsten = community.token?.originNetwork != null
          ? community.token?.originNetwork == 'ropsten'
          : false;
      dynamic communityEntities =
          await graph.getCommunityBusinesses(communityAddress);
      List<Business> businessList = new List();
      if (communityEntities != null) {
        await Future.forEach(communityEntities, (entity) async {
          dynamic metadata = await api.getEntityMetadata(
              communityAddress, entity['address'],
              isRopsten: isOriginRopsten);
          if (metadata != null) {
            entity['name'] = metadata['name'] ?? '';
            entity['metadata'] = metadata;
            entity['account'] = entity['address'] ?? '';
            businessList.add(Business.fromJson(entity));
          }
        }).then((r) {
          store.dispatch(GetBusinessListSuccess(
              businessList: businessList, communityAddress: communityAddress));
          store.dispatch(FetchingBusinessListSuccess());
        });
      }
    } catch (e) {
      logger.severe('ERROR - getBusinessListCall $e');
      store.dispatch(FetchingBusinessListFailed());
      store.dispatch(new ErrorAction('Could not get businesses list'));
    }
  };
}

ThunkAction getTokenTransfersListCall(Community community) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      wallet_core.Web3 web3 = store.state.cashWalletState.web3;
      if (web3 == null) {
        throw "Web3 is empty";
      }
      String walletAddress = store.state.userState.walletAddress;
      String tokenAddress = community?.token?.address;
      num lastBlockNumber = community?.token?.transactions?.blockNumber;
      num currentBlockNumber = await web3.getBlockNumber();
      Map<String, dynamic> response = await graph.getTransfers(
          walletAddress, tokenAddress,
          fromBlockNumber: lastBlockNumber, toBlockNumber: currentBlockNumber);
      List<Transfer> transfers = List<Transfer>.from(
          response["data"].map((json) => Transfer.fromJson(json)).toList());
      store.dispatch(new GetTokenTransfersListSuccess(
          tokenTransfers: transfers, communityAddress: community.address));
    } catch (e) {
      logger.severe('ERROR - getTokenTransfersListCall $e');
      store.dispatch(new ErrorAction('Could not get token transfers'));
    }
  };
}

ThunkAction getReceivedTokenTransfersListCall(Community community) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      String walletAddress = store.state.userState.walletAddress;
      num lastBlockNumber = community?.token?.transactions?.blockNumber;
      final String tokenAddress = community?.token?.address;
      wallet_core.Web3 web3 = store.state.cashWalletState.web3;
      if (web3 == null) {
        throw "Web3 is empty";
      }
      num currentBlockNumber = await web3.getBlockNumber();
      Map<String, dynamic> response = await graph.getReceivedTransfers(
          walletAddress, tokenAddress,
          fromBlockNumber: lastBlockNumber, toBlockNumber: currentBlockNumber);
      List<Transfer> transfers = List<Transfer>.from(
          response["data"].map((json) => Transfer.fromJson(json)).toList());
      if (transfers.isNotEmpty) {
        store.dispatch(new GetTokenTransfersListSuccess(
            tokenTransfers: transfers, communityAddress: community.address));
        store.dispatch(getTokenBalanceCall(community));
      }
    } catch (e) {
      logger.severe('ERROR - getReceivedTokenTransfersListCall $e');
      store.dispatch(new ErrorAction('Could not get token transfers'));
    }
  };
}

ThunkAction sendTokenToContactCall(
    Token token,
    String name,
    String contactPhoneNumber,
    num tokensAmount,
    VoidCallback sendSuccessCallback,
    VoidCallback sendFailureCallback,
    {String receiverName,
    String transferNote}) {
  return (Store store) async {
    final logger = await AppFactory().getLogger('action');
    try {
      logger.info('Trying to send $tokensAmount to phone $contactPhoneNumber');
      Map wallet = await api.getWalletByPhoneNumber(contactPhoneNumber);
      logger.info("wallet $wallet");
      String walletAddress = (wallet != null) ? wallet["walletAddress"] : null;
      logger.info("walletAddress $walletAddress");
      if (walletAddress == null || walletAddress.isEmpty) {
        store.dispatch(inviteAndSendCall(token, name, contactPhoneNumber,
            tokensAmount, sendSuccessCallback, sendFailureCallback,
            receiverName: receiverName));
        return;
      }
      store.dispatch(sendTokenCall(token, walletAddress, tokensAmount,
          sendSuccessCallback, sendFailureCallback,
          receiverName: receiverName, transferNote: transferNote));
    } catch (e) {
      logger.severe('ERROR - sendTokenToContactCall $e');
      store.dispatch(new ErrorAction('Could not send token to contact'));
    }
  };
}
