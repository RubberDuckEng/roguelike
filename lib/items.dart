import 'sprite.dart';
import 'model.dart';

abstract class Item {
  void onPickup(GameState state);

  Sprite get sprite;
}

class LevelMap extends Item {
  @override
  void onPickup(GameState state) {
    state.visibleChunk.revealAll();
  }

  @override
  Sprite get sprite => Sprites.map;
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
