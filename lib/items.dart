import 'drawing.dart';
import 'geometry.dart';
import 'model.dart';
import 'sprite.dart';

abstract class Mob {
  Position location;
  Direction facingDirection = Direction.up;

  Mob({required this.location});

  Drawable get drawable;

  void draw(Drawing drawing) {
    drawing.add(this, drawable, location);
  }
}

typedef ItemFactory = Item Function({required Position location});

abstract class Item extends Mob {
  Item({required super.location});

  void onPickup(GameState state);
}

class AreaReveal extends Item {
  AreaReveal({required super.location});

  @override
  void onPickup(GameState state) {
    state.revealAround(state.player.location, 10.0);
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.firework);
}

class HealOne extends Item {
  HealOne({required super.location});

  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(state, 1);
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.heart);
}

class HealAll extends Item {
  HealAll({required super.location});

  @override
  void onPickup(GameState state) {
    state.player.applyHealthChange(state, state.player.maxHealth);
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.sparkleHeart);
}

class Torch extends Item {
  Torch({required super.location});

  @override
  void onPickup(GameState state) {
    state.player.lightRadius += 1;
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.torch);
}

class MaxHealthUp extends Item {
  MaxHealthUp({required super.location});

  @override
  void onPickup(GameState state) {
    state.player.maxHealth += 1;
  }

  @override
  Drawable get drawable => const SpriteDrawable(Sprites.emptyHeart);
}
