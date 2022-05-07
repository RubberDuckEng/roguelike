import 'sprite.dart';
import 'model.dart';

abstract class Item {
  void onPickup(GameState state);

  Sprite get sprite;
}

class AreaReveal extends Item {
  @override
  void onPickup(GameState state) {
    state.revealAround(state.player.location, 10.0);
  }

  @override
  Sprite get sprite => Sprites.firework;
}

class HealOne extends Item {
  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(1);
  }

  @override
  Sprite get sprite => Sprites.heart;
}

class HealAll extends Item {
  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(state.player.maxHealth);
  }

  @override
  Sprite get sprite => Sprites.sparkleHeart;
}

class Torch extends Item {
  @override
  void onPickup(GameState state) {
    state.player.lightRadius += 1;
  }

  @override
  Sprite get sprite => Sprites.torch;
}
