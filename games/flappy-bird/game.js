(() => {
  "use strict";
  const canvas = document.getElementById("game");
  const ctx = canvas && canvas.getContext("2d");
  if (!ctx) return;

  const soundButton = document.getElementById("sound");
  const groundHeight = 58;
  let width = 0, height = 0, dpr = 1, frame = 0;
  let state = "menu", score = 0, pipes = [], clouds = [];
  let soundOn = true, audio = null;
  const bird = { x: 0, y: 0, vy: 0, rotation: 0, radius: 15 };
  const readBest = () => {
    try { return Number(window.localStorage.getItem("flappyBest") || 0); }
    catch (_) { return 0; }
  };
  let best = readBest();
  const saveBest = value => {
    try { window.localStorage.setItem("flappyBest", String(value)); }
    catch (_) { /* Storage is unavailable in some sandboxed game previews. */ }
  };

  function resize() {
    dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = Math.max(1, window.innerWidth);
    height = Math.max(1, window.innerHeight);
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    makeClouds();
    if (!bird.x) reset();
  }

  function reset() {
    bird.x = width * .28;
    bird.y = height * .42;
    bird.vy = 0;
    bird.rotation = 0;
    score = 0;
    frame = 0;
    pipes = [];
  }

  function makeClouds() {
    clouds = Array.from({ length: 6 }, () => ({
      x: Math.random() * width,
      y: 45 + Math.random() * height * .42,
      size: 18 + Math.random() * 22,
      speed: .25 + Math.random() * .35
    }));
  }

  function playSound(frequency, duration, type = "sine") {
    if (!soundOn) return;
    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return;
      audio = audio || new AudioContextClass();
      if (audio.state === "suspended") audio.resume();
      const oscillator = audio.createOscillator();
      const gain = audio.createGain();
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(frequency, audio.currentTime);
      gain.gain.setValueAtTime(.1, audio.currentTime);
      gain.gain.exponentialRampToValueAtTime(.001, audio.currentTime + duration);
      oscillator.connect(gain);
      gain.connect(audio.destination);
      oscillator.start();
      oscillator.stop(audio.currentTime + duration);
    } catch (_) { /* Audio is optional; the game still works without it. */ }
  }

  function flap() {
    if (state === "menu" || state === "gameover") {
      reset();
      state = "playing";
    }
    if (state === "playing") {
      bird.vy = -7.1;
      playSound(520, .08);
    }
  }

  function drawBackground() {
    const sky = ctx.createLinearGradient(0, 0, 0, height);
    sky.addColorStop(0, "#70c5ce");
    sky.addColorStop(1, "#c4f0e9");
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, width, height);
    ctx.fillStyle = "rgba(255,255,255,.78)";
    clouds.forEach(cloud => {
      cloud.x -= cloud.speed;
      if (cloud.x < -90) cloud.x = width + 90;
      ctx.beginPath();
      ctx.arc(cloud.x, cloud.y, cloud.size, 0, Math.PI * 2);
      ctx.arc(cloud.x + cloud.size, cloud.y - 9, cloud.size * .75, 0, Math.PI * 2);
      ctx.arc(cloud.x + cloud.size * 1.6, cloud.y, cloud.size * .85, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.fillStyle = "#a6df79";
    ctx.beginPath();
    ctx.moveTo(0, height - groundHeight);
    ctx.quadraticCurveTo(width * .25, height - 155, width * .5, height - groundHeight);
    ctx.quadraticCurveTo(width * .75, height - 135, width, height - groundHeight);
    ctx.fill();
  }

  function drawBird() {
    ctx.save();
    ctx.translate(bird.x, bird.y);
    ctx.rotate(bird.rotation);
    ctx.fillStyle = "#ffdb35";
    ctx.strokeStyle = "#a96f25";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(0, 0, 18, 14, 0, 0, Math.PI * 2);
    ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#f5b82e";
    ctx.beginPath();
    ctx.ellipse(-5, 5 + Math.sin(frame * .35) * 2, 9, 5, -.25, 0, Math.PI * 2);
    ctx.fill(); ctx.stroke();
    ctx.fillStyle = "#fff";
    ctx.beginPath(); ctx.arc(9, -6, 5.5, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#222";
    ctx.beginPath(); ctx.arc(11, -6, 2.2, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "#f47b24";
    ctx.beginPath(); ctx.moveTo(15, 0); ctx.lineTo(27, 4); ctx.lineTo(15, 8); ctx.closePath();
    ctx.fill(); ctx.stroke();
    ctx.restore();
  }

  function drawPipes() {
    pipes.forEach(pipe => {
      const bottom = pipe.top + pipe.gap;
      const gradient = ctx.createLinearGradient(pipe.x, 0, pipe.x + 65, 0);
      gradient.addColorStop(0, "#168c35");
      gradient.addColorStop(.4, "#50cf5c");
      gradient.addColorStop(1, "#13772c");
      ctx.fillStyle = gradient;
      ctx.strokeStyle = "#12652a";
      ctx.lineWidth = 2;
      ctx.fillRect(pipe.x, 0, 65, pipe.top);
      ctx.strokeRect(pipe.x, -2, 65, pipe.top + 2);
      ctx.fillRect(pipe.x - 5, pipe.top - 22, 75, 22);
      ctx.strokeRect(pipe.x - 5, pipe.top - 22, 75, 22);
      ctx.fillRect(pipe.x, bottom, 65, height - groundHeight - bottom);
      ctx.strokeRect(pipe.x, bottom, 65, height - groundHeight - bottom);
      ctx.fillRect(pipe.x - 5, bottom, 75, 22);
      ctx.strokeRect(pipe.x - 5, bottom, 75, 22);
    });
  }

  function drawGround() {
    ctx.fillStyle = "#ded895";
    ctx.fillRect(0, height - groundHeight, width, groundHeight);
    ctx.fillStyle = "#78c84b";
    ctx.fillRect(0, height - groundHeight, width, 11);
    ctx.strokeStyle = "#c5b879";
    ctx.lineWidth = 2;
    for (let x = 0; x < width; x += 30) {
      ctx.beginPath(); ctx.moveTo(x, height - 29); ctx.lineTo(x + 14, height - 24); ctx.stroke();
    }
  }

  function drawPanel(title, subtitle) {
    const panelWidth = Math.min(width - 36, 310), panelHeight = 155;
    const x = (width - panelWidth) / 2, y = Math.max(75, height / 2 - 100);
    ctx.fillStyle = "#fff5d7";
    ctx.strokeStyle = "#bd8b48";
    ctx.lineWidth = 4;
    ctx.beginPath();
    if (ctx.roundRect) ctx.roundRect(x, y, panelWidth, panelHeight, 18);
    else ctx.rect(x, y, panelWidth, panelHeight);
    ctx.fill(); ctx.stroke();
    ctx.textAlign = "center";
    ctx.fillStyle = "#e9a52f";
    ctx.font = "bold 28px system-ui";
    ctx.fillText(title, width / 2, y + 55);
    ctx.fillStyle = "#79532d";
    ctx.font = "bold 16px system-ui";
    ctx.fillText(subtitle, width / 2, y + 103);
    ctx.fillStyle = "#79532d";
    ctx.font = "bold 15px system-ui";
    ctx.fillText("BEST: " + best, width / 2, y + 132);
  }

  function drawScore() {
    ctx.textAlign = "center";
    ctx.font = "bold 48px system-ui";
    ctx.lineWidth = 5;
    ctx.strokeStyle = "#80552a";
    ctx.fillStyle = "#fff";
    ctx.strokeText(String(score), width / 2, 82);
    ctx.fillText(String(score), width / 2, 82);
  }

  function hitTest() {
    if (bird.y + bird.radius >= height - groundHeight || bird.y - bird.radius <= 0) return true;
    return pipes.some(pipe => bird.x + bird.radius > pipe.x - 5 &&
      bird.x - bird.radius < pipe.x + 70 &&
      (bird.y - bird.radius < pipe.top - 18 || bird.y + bird.radius > pipe.top + pipe.gap));
  }

  function update() {
    frame++;
    if (state !== "playing") return;
    bird.vy += .36;
    bird.y += bird.vy;
    bird.rotation = Math.min(.9, bird.vy * .08);
    const speed = Math.min(5, 2.8 + score * .055);
    if (frame % 92 === 0) {
      const gap = Math.max(128, 168 - score);
      const available = Math.max(40, height - groundHeight - gap - 130);
      pipes.push({ x: width + 20, top: 65 + Math.random() * available, gap, scored: false });
    }
    pipes.forEach(pipe => {
      pipe.x -= speed;
      if (!pipe.scored && pipe.x + 65 < bird.x) {
        pipe.scored = true;
        score++;
        playSound(850, .12);
        if (score > best) { best = score; saveBest(best); }
      }
    });
    pipes = pipes.filter(pipe => pipe.x > -90);
    if (hitTest()) {
      state = "gameover";
      playSound(120, .28, "sawtooth");
    }
  }

  function render() {
    drawBackground();
    drawPipes();
    drawBird();
    if (state === "playing") drawScore();
    if (state === "menu") drawPanel("FLAPPY BIRD", "TAP TO PLAY");
    if (state === "gameover") {
      ctx.fillStyle = "rgba(0,0,0,.3)";
      ctx.fillRect(0, 0, width, height);
      drawPanel("GAME OVER", "TAP TO TRY AGAIN");
      ctx.fillStyle = "#fff";
      ctx.textAlign = "center";
      ctx.font = "bold 23px system-ui";
      ctx.fillText("SCORE: " + score, width / 2, height / 2 + 95);
    }
    drawGround();
  }

  function loop() {
    update();
    render();
    window.requestAnimationFrame(loop);
  }

  canvas.addEventListener("pointerdown", event => {
    event.preventDefault();
    flap();
  });
  document.addEventListener("keydown", event => {
    if (event.code === "Space" || event.code === "ArrowUp") {
      event.preventDefault();
      flap();
    }
  });
  soundButton.addEventListener("click", event => {
    event.stopPropagation();
    soundOn = !soundOn;
    soundButton.textContent = soundOn ? "🔊" : "🔇";
    soundButton.setAttribute("aria-pressed", String(soundOn));
  });
  window.addEventListener("resize", resize);
  resize();
  reset();
  loop();
})();