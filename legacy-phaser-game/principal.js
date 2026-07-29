var juego = new Phaser.Game(window.innerWidth, window.innerHeight, Phaser.CANVAS, 'bloque_juego');

// Agregando los estados del juego
juego.state.add('Menu', Menu);
juego.state.add('Juego', Juego);
juego.state.add('Terminado', Terminado);

// Inicializamos el juego en el estado Menu
juego.state.start('Menu');
