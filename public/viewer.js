// 描画とファイル保存だけを受け持つ薄い JS。メッシュと STL のバイト列は Ruby が作る。
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

let renderer, scene, camera, controls, mesh, canvasEl;
let lastHeight = 0;
let framePending = false;

function requestRender() {
  if (framePending || !renderer) return;
  framePending = true;
  requestAnimationFrame(() => {
    framePending = false;
    renderer.render(scene, camera);
  });
}

function resize() {
  const w = canvasEl.clientWidth, h = canvasEl.clientHeight;
  if (w === 0 || h === 0) return;
  renderer.setSize(w, h, false);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
  requestRender();
}

function concat(parts) {
  let n = 0;
  for (const p of parts) n += p.length;
  const out = new Uint8Array(n);
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

function frame(height) {
  camera.position.set(height * 0.9, -height * 2.0, height * 1.0);
  controls.target.set(0, 0, height / 2);
  controls.update();
}

window.HaniwaJS = {
  initViewer(canvas) {
    canvasEl = canvas;
    renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(35, 1, 1, 5000);
    camera.up.set(0, 0, 1); // 印刷時と同じく Z を上にする
    scene.add(new THREE.HemisphereLight(0xfff4e6, 0x8a7460, 1.6));
    const key = new THREE.DirectionalLight(0xffffff, 2.2);
    camera.add(key);
    key.position.set(-60, 80, 40);
    scene.add(camera);

    // 造形面 (Bambu A1 Mini: 180 x 180 mm)
    const bed = new THREE.Mesh(
      new THREE.PlaneGeometry(180, 180),
      new THREE.MeshBasicMaterial({ color: 0x8a7460, transparent: true, opacity: 0.12, side: THREE.DoubleSide })
    );
    scene.add(bed);
    const grid = new THREE.GridHelper(180, 18, 0x8a7460, 0x8a7460);
    grid.rotation.x = Math.PI / 2;
    grid.material.transparent = true;
    grid.material.opacity = 0.25;
    scene.add(grid);

    mesh = new THREE.Mesh(
      new THREE.BufferGeometry(),
      new THREE.MeshStandardMaterial({ color: 0xc9834f, roughness: 0.9, metalness: 0.0 })
    );
    scene.add(mesh);

    controls = new OrbitControls(camera, canvas);
    controls.enableDamping = false;
    controls.addEventListener('change', requestRender);
    new ResizeObserver(resize).observe(canvas);
    frame(80);
    resize();
  },

  // positions: float32 の小端バイト列、indices: uint32 の小端バイト列 (どちらも Uint8Array の配列)
  setMesh(posParts, idxParts, height) {
    const pos = concat(posParts);
    const idx = concat(idxParts);
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(pos.buffer), 3));
    geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(idx.buffer), 1));
    geometry.computeVertexNormals();
    mesh.geometry.dispose();
    mesh.geometry = geometry;
    if (lastHeight === 0) {
      frame(height);
    } else if (height !== lastHeight) {
      // 高さを変えても同じ向き・同じ見かけの大きさで見えるようにする
      const k = height / lastHeight;
      const offset = camera.position.clone().sub(controls.target).multiplyScalar(k);
      controls.target.set(0, 0, height / 2);
      camera.position.copy(controls.target).add(offset);
      controls.update();
    }
    lastHeight = height;
    requestRender();
    window.__haniwaMesh = { vertices: pos.length / 12, triangles: idx.length / 12, height };
  },

  resetView() {
    frame(lastHeight || 80);
    requestRender();
  },

  bytesFromArray(values) {
    return Uint8Array.from(values);
  },

  download(parts, filename) {
    const blob = new Blob(parts, { type: 'model/stl' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 10000);
    window.__haniwaDownload = { blob, filename, size: blob.size };
    return blob.size;
  }
};
