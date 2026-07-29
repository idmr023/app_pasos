var nave;
var asteroides;
var timer;
var asteroidesEsquivados = 0;
var nivel = 1;
var velocidadAsteroides = 100;
var textoNivel;
var reconocimientoVoz; 
var nombreCreador = "Ivan Daniel Manrique Roa";
var movimientoEnCurso = 0; // Estado de movimiento: 0 = detenido, 1 = izquierda, 2 = derecha.

// Menú principal del juego.
var Menu = {
    preload: function () {
        // Carga los recursos necesarios para el menú (fondo y botón).
        juego.load.image('fondo', 'img/bg.png');
        juego.load.image('boton', 'img/boton.png');
    },

    create: function () {
        // Configura el fondo y ajusta su tamaño al de la pantalla.
        var fondo = juego.add.sprite(0, 0, 'fondo');
        fondo.width = juego.width;
        fondo.height = juego.height;

        // Añade el título del juego centrado en la pantalla.
        var titulo = juego.add.text(juego.width / 2, juego.height / 3, 'Asteroids', {
            font: '40px Arial',
            fill: '#ffffff'
        });
        titulo.anchor.setTo(0.5);

        // Crea un botón para iniciar el juego.
        var botonIniciar = juego.add.button(juego.width / 2, juego.height / 1.5, 'boton', function () {
            juego.state.start('Juego'); // Cambia al estado "Juego".
        });
        botonIniciar.anchor.setTo(0.5);

        // Añade un texto con el nombre del creador.
        juego.add.text(juego.width / 2, juego.height / 2.6, 'Creador: ' + nombreCreador, {
            font: '20px Arial',
            fill: '#ffffff'
        }).anchor.setTo(0.5);
    }
};

var Juego = {
    nave: null,
    asteroides: null,
    timer: null,
    asteroidesEsquivados: 0,
    nivel: 1,
    velocidadAsteroides: 100,
    textoNivel: null,
    reconocimientoVoz: null,
    movimientoEnCurso: 0,
    nombreCreador: "Ivan Daniel Manrique Roa",

    preload: function () {
        juego.load.image('nave', 'img/nave.png');
        juego.load.image('asteroide', 'img/malo.png');
        juego.load.image('bg', 'img/bg.png');
        juego.load.image('enemigo2', 'img/enemigos2.png'); // Asegúrate de cargar la imagen enemigo2.
        juego.load.audio('musicaFondo', 'audio/fondo.mp3');
        juego.load.audio('sonidoEsquivar', 'audio/esquivar.mp3');
    },

    create: function () {
        juego.add.tileSprite(0, 0, juego.width, juego.height, 'bg');
        juego.physics.startSystem(Phaser.Physics.ARCADE);

        Juego.nave = juego.add.sprite(juego.width / 2, juego.height - 100, 'nave');
        Juego.nave.anchor.setTo(0.5);
        juego.physics.arcade.enable(Juego.nave);
        Juego.nave.body.collideWorldBounds = true;
        Juego.nave.body.setSize(50, 50, 0, 0);

        Juego.crearAsteroides();
        Juego.timer = juego.time.events.loop(2000, Juego.crearAsteroide, Juego);

        Juego.textoNivel = juego.add.text(10, 10, 'Nivel: 1\nAsteroides Esquivados: 0', {
            font: '20px Arial',
            fill: '#ffffff'
        });

        Juego.musicaFondo = juego.add.audio('musicaFondo');
        Juego.musicaFondo.loop = true;
        Juego.musicaFondo.play();

        Juego.sonidoEsquivar = juego.add.audio('sonidoEsquivar');
        Juego.iniciarReconocimientoVoz();
    },

    crearAsteroides: function () {
        Juego.asteroides = juego.add.group();
        Juego.asteroides.enableBody = true;
        Juego.asteroides.createMultiple(50, 'asteroide');
        Juego.asteroides.setAll('anchor.x', 0.5);
        Juego.asteroides.setAll('anchor.y', 0.5);
        Juego.asteroides.setAll('checkWorldBounds', true);
        Juego.asteroides.setAll('outOfBoundsKill', true);
    },

    crearAsteroide: function () {
        var asteroide;
        if (Juego.nivel >= 2) {
            asteroide = Juego.asteroides.getFirstDead();
            asteroide.reset(Math.floor(Math.random() * (juego.width / 38)) * 38, 0);
            asteroide.loadTexture('enemigo2');
        } else {
            asteroide = Juego.asteroides.getFirstDead();
            asteroide.reset(Math.floor(Math.random() * (juego.width / 38)) * 38, 0);
            asteroide.loadTexture('asteroide');
        }
        asteroide.anchor.setTo(0.5);
        asteroide.body.velocity.y = Juego.velocidadAsteroides;
    },

    iniciarReconocimientoVoz: function () {
        if (!('webkitSpeechRecognition' in window)) {
            console.error('El reconocimiento de voz no es compatible con este navegador.');
            return;
        }

        Juego.reconocimientoVoz = new webkitSpeechRecognition();
        Juego.reconocimientoVoz.continuous = true;
        Juego.reconocimientoVoz.interimResults = false;
        Juego.reconocimientoVoz.lang = 'es-ES';

        Juego.reconocimientoVoz.onresult = function (event) {
            var resultado = event.results[event.resultIndex];
            if (resultado.isFinal) {
                var comando = resultado[0].transcript.trim().toLowerCase();
                console.log('Comando reconocido:', comando);
                Juego.controlarNave(comando);
            }
        };

        Juego.reconocimientoVoz.onerror = function (event) {
            console.error('Error en el reconocimiento de voz: ', event.error);
        };

        Juego.reconocimientoVoz.start();
    },

    controlarNave: function (comando) {
        const movimientos = {
            'izquierda.': -1,
            'derecha.': 1
        };

        if (movimientos[comando]) {
            Juego.moverNave(movimientos[comando]);
        } else {
            console.log('Comando no reconocido:', comando);
        }
    },

    moverNave: function (direccion) {
        const VELOCIDAD_MAXIMA = 200;
        const ACELERACION = 150;

        Juego.nave.body.acceleration.x = direccion * ACELERACION;
        Juego.nave.body.velocity.x = Phaser.Math.clamp(Juego.nave.body.velocity.x, -VELOCIDAD_MAXIMA, VELOCIDAD_MAXIMA);
    },

    actualizarTextoNivel: function () {
        Juego.textoNivel.setText('Nivel: ' + Juego.nivel + '\nAsteroides Esquivados: ' + Juego.asteroidesEsquivados);
    },

    update: function () {
        juego.physics.arcade.collide(Juego.nave, Juego.asteroides, Juego.perder, null, Juego);

        Juego.asteroides.forEachAlive(function (asteroide) {
            if (asteroide.y > juego.height && !asteroide.esquivado) {
                Juego.asteroidesEsquivados++;
                Juego.sonidoEsquivar.play();
                Juego.actualizarTextoNivel();

                asteroide.esquivado = true;

                if (Juego.asteroidesEsquivados > 5) {
                    Juego.nivel = 2;
                    Juego.velocidadAsteroides = 150;
                    console.log('Nivel 2 alcanzado!');
                }
            }
        });
    },

    perder: function () {
        location.reload(); // Recargar la página al perder
    }
};
