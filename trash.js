window.delList = JSON.parse(localStorage.getItem("del_ords") || "[]");
function updCnt() { const e = document.getElementById("tCnt"); if (e) e.textContent = window.delList.length; }
window.delOrd = async function(id) {
  const ord = currentOrders.find(o => o.id === id);
  if (!confirm("Delete " + (ord ? ord.poNumber : "stop") + "?")) return;
  if (ord) { window.delList.push(ord); localStorage.setItem("del_ords", JSON.stringify(window.delList)); updCnt(); }
  await db.collection("orders").doc(id).delete();
};
window.openRestore = function() {
  let m = document.getElementById("rModal");
  if (!m) {
    m = document.createElement("div"); m.id = "rModal";
    m.style.cssText = "position:fixed;inset:0;background:rgba(0,0,0,.8);z-index:9999;display:flex;align-items:center;justify-content:center;padding:15px;";
    document.body.appendChild(m);
  }
  const items = window.delList.length ? window.delList.map((o, i) => `<div style="display:flex;justify-content:space-between;align-items:center;background:#1e293b;padding:8px;border-radius:6px;margin-bottom:6px;"><div><b>${o.poNumber||"PO"}</b> - ${o.customer||""}</div><button class="btn btn-primary" style="padding:4px 8px;margin:0;" onclick="resOrd(${i})">Restore</button></div>`).join("") : "<p style='color:#94a3b8;text-align:center;'>Trash is empty.</p>";
  m.innerHTML = `<div style="background:#0f172a;border:1px solid #334155;border-radius:10px;max-width:450px;width:100%;padding:16px;"><div style="display:flex;justify-content:space-between;margin-bottom:10px;"><h3 style="margin:0;color:#fff;">Deleted Stops</h3><button onclick="document.getElementById('rModal').style.display='none'" style="background:none;border:none;color:#fff;font-size:1.4rem;">&times;</button></div>${items}</div>`;
  m.style.display = "flex";
};
window.resOrd = async function(i) {
  const o = window.delList[i]; if (!o) return;
  const d = Object.assign({}, o); delete d.id;
  await db.collection("orders").doc(o.id || ("R_" + Date.now())).set(d);
  window.delList.splice(i, 1); localStorage.setItem("del_ords", JSON.stringify(window.delList)); updCnt(); openRestore();
};
setTimeout(updCnt, 1000);
