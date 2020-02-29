import 'package:redux/redux.dart';

double update(double state, dynamic action) {
  return action;
}

final store = new Store<double>(update, initialState: 0);