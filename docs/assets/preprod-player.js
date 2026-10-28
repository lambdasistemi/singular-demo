const recording = document.getElementById('preprod-recording');
if (recording) {
  window.AsciinemaPlayer.create(
    new URL(recording.dataset.recording, document.baseURI).href,
    recording,
    {
      cols: 110,
      rows: 34,
      fit: 'width',
      idleTimeLimit: 3600,
      markers: JSON.parse(recording.dataset.markers),
    },
  );
}
