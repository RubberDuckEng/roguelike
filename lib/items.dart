import 'drawing.dart';
import 'model.dart';
import 'sprite.dart';

abstract class Item {
  void onPickup(GameState state);

  Drawable get drawable;
}

class AreaReveal extends Item {
  @override
  void onPickup(GameState state) {
    state.revealAround(state.player.location, 10.0);
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.firework);
}

class HealOne extends Item {
  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(1);
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.heart);
}

class HealAll extends Item {
  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(state.player.maxHealth);
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.sparkleHeart);
}

class Torch extends Item {
  @override
  void onPickup(GameState state) {
    state.player.lightRadius += 1;
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.torch);
}
