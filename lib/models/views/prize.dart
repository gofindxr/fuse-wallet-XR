import 'package:equatable/equatable.dart';
import 'package:BIM/models/plugins/plugins.dart';
import 'package:redux/redux.dart';
import 'package:BIM/models/app_state.dart';
import 'package:BIM/models/community.dart';

class PrizeViewModel extends Equatable {
  final Plugins plugins;

  PrizeViewModel({this.plugins});

  static PrizeViewModel fromStore(Store<AppState> store) {
    String communityAddres = store.state.cashWalletState.communityAddress;
    Community community =
        store.state.cashWalletState.communities[communityAddres] ??
            new Community.initial();
    return PrizeViewModel(plugins: community?.plugins);
  }

  @override
  List<Object> get props => [plugins];
}
