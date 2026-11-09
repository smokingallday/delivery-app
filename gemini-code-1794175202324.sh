cd ~/super-delivery
cat << 'EOF' > delivery-app.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
  <title>Delivery Command | Driver Unit</title>

  <!-- External CDNs -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js"></script>

  <!-- Firebase Cloud Sync & Persistence -->
  <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js"></script>
  <script src="https://www.gstatic.com/firebasejs/10.7.1/firebase-firestore-compat.js"></script>

  <style>
    :root {
      --bg: #0f172a; --card: #1e293b; --border: #334155; --accent: #38bdf8;
      --primary: #2563eb; --success: #16a34a; --warning: #f59e0b; --danger: #ef4444;
      --text: #f8fafc; --muted: #94a3b8;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: var(--bg); color: var(--text); padding-bottom: 80px; min-height: 100vh; }

    header {
      background: #090e1f; padding: 14px 18px; border-bottom: 1px solid var(--border);
      display: flex; justify-content: space-between; align-items: center; position: sticky; top: 0; z-index: 40;
    }
    header h1 { font-size: 1.1rem; font-weight: 700; color: #fff; }
    .status-badge { font-size: 0.75rem; color: var(--accent); background: rgba(56, 189, 248, 0.15); padding: 4px 8px; border-radius: 999px; }

    .nav-bar {
      position: fixed; bottom: 0; left: 0; right: 0; background: #090e1f;
      display: flex; border-top: 1px solid var(--border); z-index: 50; height: 60px;
    }
    .nav-btn {
      flex: 1; border: none; background: none; color: var(--muted); font-size: 0.85rem;
      font-weight: 600; cursor: pointer; display: flex; align-items: center; justify-content: center;
    }
    .nav-btn.active { color: var(--accent); border-top: 2px solid var(--accent); }

    .container { padding: 16px; max-width: 600px; margin: 0 auto; }
    .screen { display: none; }
    .screen.active { display: block; }

    .card {
      background: var(--card); border: 1px solid var(--border); border-radius: 8px;
      padding: 16px; margin-bottom: 14px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.3);
    }
    .card-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
    .badge { padding: 4px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; }
    .badge-pending { background: #78350f; color: #fde68a; }
    .badge-intransit { background: #1e3a8a; color: #93c5fd; }
    .badge-delivered { background: #14532d; color: #86efac; }
    .badge-oversize { background: #7f1d1d; color: #fecaca; font-size: 0.7rem; border: 1px solid var(--danger); margin-top: 6px; display: inline-block; }

    .btn {
      display: inline-block; width: 100%; padding: 12px; margin-top: 10px; border: none;
      border-radius: 6px; font-weight: 600; cursor: pointer; text-align: center; font-size: 0.95rem;
    }
    .btn-maps { background: #0284c7; color: #fff; margin-top: 0; }
    .btn-run { background: #eab308; color: #000; margin-top: 0; }
    .btn-pod { background: var(--success); color: #fff; margin-top: 0; }

    .actions-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 12px; }

    /* POD Modal */
    .modal {
      display: none; position: fixed; top: 0; left: 0; right: 0; bottom: 0;
      background: rgba(0,0,0,0.85); z-index: 100; padding: 16px; overflow-y: auto;
    }
    .modal.active { display: flex; align-items: center; justify-content: center; }
    .modal-content { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 20px; width: 100%; max-width: 500px; }
    canvas { background: #fff; border-radius: 6px; width: 100%; height: 140px; touch-action: none; margin-top: 6px; }
    label { display: block; font-size: 0.8rem; color: var(--muted); margin-top: 12px; margin-bottom: 4px; text-transform: uppercase; font-weight: 600; }
    input[type="text"] { width: 100%; padding: 10px; background: #090e1f; border: 1px solid var(--border); border-radius: 6px; color: #fff; font-size: 1rem; }
  </style>
</head>
<body>

  <header>
    <h1>Borray Field Unit</h1>
    <div id="sync-status" class="status-badge">● Cloud Connected</div>
  </header>

  <div class="container">
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:12px;">
      <h2 style="font-size: 1.1rem;">Active Queue</h2>
      <button onclick="exportDailyManifest()" style="background:#334155; color:#fff; border:none; padding:6px 12px; border-radius:4px; font-size:0.8rem; font-weight:600;">📊 Export Sheet</button>
    </div>
    <div id="orders-list">Connecting to dispatch...</div>
  </div>

  <!-- POD Sign-Off Modal -->
  <div id="podModal" class="modal">
    <div class="modal-content">
      <h3 style="color:var(--accent); margin-bottom:6px;">Proof of Delivery</h3>
      <p id="podOrderInfo" style="font-size:0.85rem; color:var(--muted); margin-bottom:12px;"></p>

      <label>Drop-off Photo</label>
      <input type="file" id="podPhoto" accept="image/*" capture="environment" style="color:var(--muted);" />

      <label>Customer Signature</label>
      <canvas id="sigCanvas"></canvas>
      <button onclick="clearSignature()" style="background:none; border:none; color:var(--accent); font-size:0.8rem; cursor:pointer; margin-top:4px;">Clear Signature</button>

      <label>Received By (Print Name)</label>
      <input type="text" id="signerName" placeholder="Recipient Name" required />

      <button class="btn btn-pod" onclick="submitPod()">Confirm & Finalize Delivery</button>
      <button class="btn" style="background:#334155; color:#fff;" onclick="closePodModal()">Cancel</button>
    </div>
  </div>

  <script>
    // --- FIREBASE CONFIGURATION ---
    const firebaseConfig = {
      apiKey: "AIzaSyCes7q2ekpluK_QBpcDPb6iaIxljDQZ5dY",
      authDomain: "borray-delivery-dispatch.firebaseapp.com",
      projectId: "borray-delivery-dispatch",
      storageBucket: "borray-delivery-dispatch.firebasestorage.app",
      messagingSenderId: "385282448736",
      appId: "1:385282448736:web:a8e60e605c20c0a7229205"
    };

    firebase.initializeApp(firebaseConfig);
    const db = firebase.firestore();

    // Enable multi-tab offline persistence
    db.enablePersistence({ synchronizeTabs: true }).catch((err) => {
      console.warn("Offline persistence note:", err.code);
    });

    let currentOrders = [];
    let activePodOrder = null;

    // Real-Time Queue Listener
    db.collection('orders').orderBy('createdAt', 'desc').onSnapshot((snapshot) => {
      currentOrders = [];
      snapshot.forEach(doc => currentOrders.push(doc.data()));
      renderOrders();
    }, (err) => {
      document.getElementById('sync-status').textContent = "⚠️ Offline Mode";
      document.getElementById('sync-status').style.color = "var(--warning)";
    });

    function renderOrders() {
      const listEl = document.getElementById('orders-list');
      if (currentOrders.length === 0) {
        listEl.innerHTML = '<div style="color:var(--muted); text-align:center; padding:2rem 0;">No active dispatches. Waiting for office...</div>';
        return;
      }

      listEl.innerHTML = currentOrders.map(ord => {
        const norm = (ord.status || 'pending').replace(/\s+/g, '').toLowerCase();
        const isPending = ord.status === 'Pending';
        const isTransit = ord.status === 'In Transit';
        const isDelivered = ord.status === 'Delivered';

        return `
          <div class="card">
            <div class="card-top">
              <strong style="font-size:1.1rem; color:#fff;">${ord.poNumber}</strong>
              <span class="badge badge-${norm}">${ord.status}</span>
            </div>
            <div style="color:var(--accent); font-weight:600; font-size:0.95rem;">${ord.customer}</div>
            <p style="font-size:0.85rem; margin-top:4px;">📍 ${ord.destination}</p>
            <p style="font-size:0.8rem; color:var(--muted); margin-top:4px;">
              ${ord.length}"L × ${ord.width}"W × ${ord.height}"H (${ord.cubicFt} cu ft)
            </p>
            ${ord.isOversize ? '<div class="badge badge-oversize">⚠️ OVERSIZE FOR IONIQ 5</div>' : ''}
            ${ord.notes ? `<p style="font-size:0.8rem; color:var(--muted); margin-top:6px; font-style:italic;">Notes: ${ord.notes}</p>` : ''}

            <div class="actions-grid">
              <button class="btn btn-maps" onclick="openMaps('${encodeURIComponent(ord.destination)}')">🗺️ Navigate</button>
              ${isPending ? `<button class="btn btn-run" onclick="updateStatus('${ord.id}', 'In Transit')">Start Run</button>` : ''}
              ${isTransit ? `<button class="btn btn-pod" onclick="openPodModal('${ord.id}')">POD Sign-off</button>` : ''}
              ${isDelivered ? `<div style="grid-column:1/-1; font-size:0.8rem; color:var(--success); margin-top:4px;">✓ Delivered to ${ord.signerName || 'Receiver'}</div>` : ''}
            </div>
          </div>
        `;
      }).join('');
    }

    window.openMaps = function(dest) {
      window.open(`https://www.google.com/maps/dir/?api=1&destination=${dest}`, "_blank");
    };

    window.updateStatus = async function(id, status) {
      await db.collection('orders').doc(id).update({ status: status });
    };

    // Canvas Signature Pad
    const canvas = document.getElementById("sigCanvas");
    const ctx = canvas.getContext("2d");
    let isDrawing = false;

    function resizeCanvas() {
      canvas.width = canvas.parentElement.clientWidth - 40;
      canvas.height = 140;
      ctx.lineWidth = 2;
      ctx.strokeStyle = "#000";
    }

    canvas.addEventListener("touchstart", (e) => {
      e.preventDefault();
      isDrawing = true;
      const rect = canvas.getBoundingClientRect();
      ctx.beginPath();
      ctx.moveTo(e.touches[0].clientX - rect.left, e.touches[0].clientY - rect.top);
    }, { passive: false });

    canvas.addEventListener("touchmove", (e) => {
      e.preventDefault();
      if (!isDrawing) return;
      const rect = canvas.getBoundingClientRect();
      ctx.lineTo(e.touches[0].clientX - rect.left, e.touches[0].clientY - rect.top);
      ctx.stroke();
    }, { passive: false });

    window.addEventListener("touchend", () => { isDrawing = false; });

    window.clearSignature = function() {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
    };

    window.openPodModal = function(id) {
      activePodOrder = currentOrders.find(o => o.id === id);
      if (!activePodOrder) return;
      document.getElementById('podOrderInfo').textContent = `${activePodOrder.poNumber} — ${activePodOrder.customer}`;
      document.getElementById('podModal').classList.add('active');
      setTimeout(resizeCanvas, 50);
    };

    window.closePodModal = function() {
      document.getElementById('podModal').classList.remove('active');
      clearSignature();
      document.getElementById('signerName').value = '';
    };

    window.submitPod = async function() {
      const signer = document.getElementById('signerName').value.trim();
      if (!signer) {
        alert("Please enter recipient name.");
        return;
      }

      const sigData = canvas.toDataURL("image/png");
      const photoInput = document.getElementById('podPhoto');
      let photoData = null;

      if (photoInput.files && photoInput.files[0]) {
        photoData = await compressImage(photoInput.files[0]);
      }

      await db.collection('orders').doc(activePodOrder.id).update({
        status: 'Delivered',
        signerName: signer,
        signatureData: sigData,
        photoData: photoData,
        deliveredAt: new Date().toISOString()
      });

      closePodModal();
    };

    function compressImage(file) {
      return new Promise((resolve) => {
        const reader = new FileReader();
        reader.onload = (e) => {
          const img = new Image();
          img.onload = () => {
            const oc = document.createElement('canvas');
            const maxW = 800;
            const scale = Math.min(1, maxW / img.width);
            oc.width = img.width * scale;
            oc.height = img.height * scale;
            const octx = oc.getContext('2d');
            octx.drawImage(img, 0, 0, oc.width, oc.height);
            resolve(oc.toDataURL('image/jpeg', 0.7));
          };
          img.src = e.target.result;
        };
        reader.readAsDataURL(file);
      });
    }

    window.exportDailyManifest = function() {
      if (!currentOrders.length) {
        alert("No deliveries found to export.");
        return;
      }
      const rows = currentOrders.map(o => ({
        "PO / Invoice #": o.poNumber,
        "Customer": o.customer,
        "Destination Address": o.destination,
        "Dimensions": `${o.length}" × ${o.width}" × ${o.height}"`,
        "Cubic Feet": o.cubicFt,
        "Status": o.status,
        "Signer Name": o.signerName || "N/A",
        "Delivered Timestamp": o.deliveredAt ? new Date(o.deliveredAt).toLocaleString() : "N/A"
      }));
      const ws = XLSX.utils.json_to_sheet(rows);
      const wb = XLSX.utils.book_new();
      XLSX.utils.book_append_sheet(wb, ws, "Manifest");
      XLSX.writeFile(wb, `delivery-manifest-${new Date().toISOString().slice(0, 10)}.xlsx`);
    };
  </script>
</body>
</html>
EOF