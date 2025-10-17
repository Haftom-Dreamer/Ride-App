// Translation function for dynamic content
if (typeof window.DashboardLANG === 'undefined') {
    window.DashboardLANG = window.TEMPLATE_VARS?.LANG || 'en';
}
const LANG = window.DashboardLANG;
const TRANSLATIONS = {};
const t = (key) => TRANSLATIONS[LANG]?.[key] || key;

const updateFilenameLabel = (inputId, labelId) => { 
    const input = document.getElementById(inputId); 
    const label = document.getElementById(labelId); 
    label.textContent = input.files.length > 0 ? input.files[0].name : t('no_file_chosen'); 
};

document.addEventListener('DOMContentLoaded', () => {
    // --- STATE & CONFIG ---
    const API_BASE_URL = window.TEMPLATE_VARS?.API_BASE_URL || 'http://127.0.0.1:5000/api';
    let dashboardMap, revenueChart, vehicleDistChart, paymentDistChart;
    let rideLayers = {};
    let currentAnalyticsParams = 'period=week';
    let currentReportParams = 'period=all';
    let allDrivers = [], allRidesHistory = [], allFeedback = [], allPendingRides = [], allActiveRides = [], allPassengers = [], recentNotifications = [];
    let rideHistoryPage = 1, RIDES_PER_PAGE = 10, lastPendingCount = 0;
    // Audio notification with user interaction requirement
    let notificationSound = null;
    let audioInitialized = false;
    
    const initAudio = () => {
        if (!audioInitialized) {
            try {
                notificationSound = new Audio("data:audio/wav;base64,UklGRl9vT19XQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YU"+Array(500).join("12345678"));
                notificationSound.volume = 0.3; // Lower volume
                audioInitialized = true;
            } catch (error) {
                console.warn('Audio initialization failed:', error);
            }
        }
    };
    
    const playNotificationSound = () => {
        if (notificationSound && audioInitialized) {
            try {
                notificationSound.play().catch(error => {
                    console.log('Audio play failed (user interaction required):', error.message);
                });
            } catch (error) {
                console.log('Audio play error:', error.message);
            }
        }
    };
    const getCssVar = (varName) => getComputedStyle(document.documentElement).getPropertyValue(varName).trim();
    const chartTextColor = () => getCssVar('--text-primary');
    const pendingIcon = L.icon({ iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-blue.png', shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png', iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41] });
    const activeIcon = L.icon({ iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png', shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png', iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41] });
    const destIcon = L.icon({ iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png', shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/0.7.7/images/marker-shadow.png', iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41] });

    // --- HELPER FUNCTIONS ---
    // Rate limiting protection
    const requestQueue = new Map();
    const RATE_LIMIT_DELAY = 500; // 500ms between requests to same endpoint
    
    // Smart caching to reduce API calls
    const cache = new Map();
    const CACHE_DURATION = 5000; // 5 seconds cache for dashboard data
    
    const fetchData = async (endpoint, params = '', useCache = true) => { 
        const key = `${endpoint}?${params}`;
        const now = Date.now();
        
        // Check cache first for dashboard endpoints
        if (useCache && cache.has(key)) {
            const cached = cache.get(key);
            if (now - cached.timestamp < CACHE_DURATION) {
                console.log(`Using cached data for ${endpoint}`);
                return cached.data;
            }
        }
        
        // Check if we made a request to this endpoint recently
        if (requestQueue.has(key)) {
            const lastRequest = requestQueue.get(key);
            const timeSinceLastRequest = now - lastRequest;
            
            if (timeSinceLastRequest < RATE_LIMIT_DELAY) {
                const waitTime = RATE_LIMIT_DELAY - timeSinceLastRequest;
                console.log(`Rate limiting: waiting ${waitTime}ms before next request to ${endpoint}`);
                await new Promise(resolve => setTimeout(resolve, waitTime));
            }
        }
        
        requestQueue.set(key, now);
        
        let r; 
        try { 
            r = await fetch(`${API_BASE_URL}/${endpoint}?${params}`, { cache: "no-store", credentials: 'include' }); 
            if (!r.ok) {
                if (r.status === 429) {
                    console.warn(`Rate limited for ${endpoint}, will retry later`);
                    return null; // Don't throw error for rate limiting
                }
                throw new Error(`HTTP error ${r.status}`); 
            }
            const data = await r.json();
            
            // Cache the result for dashboard endpoints
            if (useCache && ['dashboard-stats', 'pending-rides', 'active-rides', 'available-drivers'].includes(endpoint)) {
                cache.set(key, { data, timestamp: now });
            }
            
            return data;
        } catch (e) { 
            console.error(`Fetch error for ${endpoint}:`, e); 
            if (r && r.status === 401) { window.location.href = '/login'; } 
            return null; 
        } 
    };
    
    const postData = async (endpoint, data, method = 'POST') => { 
        let r; 
        try { 
            r = await fetch(`${API_BASE_URL}/${endpoint}`, { method: method, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data), credentials: 'include' }); 
            const result = await r.json(); 
            if (!r.ok) throw new Error(result.error || `HTTP error ${r.status}`); 
            return result; 
        } catch (e) { 
            console.error(`Post error for ${endpoint}:`, e); 
            if (r && r.status === 401) { window.location.href = '/login'; } 
            return {error: e.message}; 
        } 
    };
    
    const postFormData = async (endpoint, formData) => { 
        try { 
            const r = await fetch(`${API_BASE_URL}/${endpoint}`, { method: 'POST', body: formData, credentials: 'include' }); 
            if (!r.ok) { 
                let err;
                const contentType = r.headers.get('content-type');
                if (contentType && contentType.includes('application/json')) {
                    err = await r.json();
                } else {
                    // Server returned HTML instead of JSON (likely an error page)
                    err = { error: `Server error (${r.status}). Please check your session and try again.` };
                }
                throw new Error(err.error || `HTTP error ${r.status}`); 
            } 
            return await r.json(); 
        } catch (e) { 
            console.error(`Post Form error for ${endpoint}:`, e); 
            alert(`Error: ${e.message || 'Failed to save. Please try again.'}`); 
            if (e.message && (e.message.includes('401') || e.message.includes('Session'))) { 
                window.location.href = '/login'; 
            } 
            return {error: e.message}; 
        } 
    };
    const showModal = (id) => { 
        hideModals(); 
        document.getElementById(id).classList.remove('hidden'); 
        document.getElementById(id).classList.add('flex'); 
    };
    
    const hideModals = () => document.querySelectorAll('.modal').forEach(m => { 
        m.classList.add('hidden'); 
        m.classList.remove('flex'); 
    });

    // --- UI & NAVIGATION ---
    const showPane = (paneId) => { 
        document.querySelectorAll('.pane').forEach(p => p.classList.remove('active')); 
        const targetPane = document.getElementById(`${paneId}-pane`);
        if (targetPane) {
            targetPane.classList.add('active'); 
        }
        document.querySelectorAll('.sidebar-link').forEach(l => l.classList.remove('active')); 
        const activeLink = document.querySelector(`.sidebar-link[data-pane="${paneId}"]`); 
        if(activeLink) { 
            activeLink.classList.add('active'); 
            document.getElementById('pane-title').textContent = activeLink.title;
        } 
        if (paneId === 'dashboard' && !dashboardMap) initDashboardMap(); 
         if (paneId === 'analytics') {
             console.log('Analytics pane activated, calling updateAnalytics');
             updateAnalytics();
         }
        if (paneId === 'inbox') refreshFeedback(); 
        if (paneId === 'support-tickets') refreshSupportTickets(); 
        if(paneId === 'settings') refreshAdminUsers(); 
        if (dashboardMap) setTimeout(() => dashboardMap.invalidateSize(), 310); 
    };

    // Make showPane globally accessible
    window.showPane = showPane;
    
    document.querySelectorAll('.sidebar-link').forEach(link => { 
        if (link.dataset.pane) { 
            link.addEventListener('click', e => { 
                e.preventDefault(); 
                showPane(link.dataset.pane); 
            }); 
        } 
    });

    // --- DARK MODE & SIDEBAR ---
    document.getElementById('sidebar-toggle-btn').addEventListener('click', () => { 
        document.getElementById('main-wrapper').classList.toggle('sidebar-collapsed'); 
        localStorage.setItem('sidebarCollapsed', document.getElementById('main-wrapper').classList.contains('sidebar-collapsed')); 
        setTimeout(() => { if (dashboardMap) dashboardMap.invalidateSize(); }, 300); 
    });
    
    if (localStorage.getItem('sidebarCollapsed') === 'true') document.getElementById('main-wrapper').classList.add('sidebar-collapsed');
    
    const setDarkMode = (isDark) => { 
        if (isDark) { 
            document.documentElement.classList.add('dark'); 
            document.getElementById('dark-mode-icon').textContent = '🌙'; 
        } else { 
            document.documentElement.classList.remove('dark'); 
            document.getElementById('dark-mode-icon').textContent = '☀️'; 
        } 
        localStorage.setItem('dispatcherDarkMode', isDark); 
        if (document.getElementById('analytics-pane').classList.contains('active')) updateAnalytics(); 
    };
    
    document.getElementById('dark-mode-toggle-checkbox').addEventListener('change', (e) => setDarkMode(e.target.checked));
    if (localStorage.getItem('dispatcherDarkMode') === 'true') { 
        document.getElementById('dark-mode-toggle-checkbox').checked = true; 
        setDarkMode(true); 
    } else { 
        setDarkMode(false); 
    }

    // --- MODAL & FORM LOGIC ---
    document.getElementById('add-driver-btn').addEventListener('click', () => showModal('add-driver-modal'));
    
    document.querySelectorAll('.modal').forEach(modal => modal.addEventListener('click', e => { 
        if (e.target.classList.contains('modal') || e.target.classList.contains('cancel-modal-btn')) hideModals(); 
    }));
    
    document.getElementById('add-driver-form').addEventListener('submit', async e => { 
        e.preventDefault(); 
        await postFormData('add-driver', new FormData(e.target)); 
        hideModals(); 
        e.target.reset(); 
        refreshAllData(); 
    });
    
    document.getElementById('edit-driver-form').addEventListener('submit', async e => { 
        e.preventDefault(); 
        const formData = new FormData(e.target); 
        await postFormData(`update-driver/${formData.get('id')}`, formData); 
        hideModals(); 
        refreshAllData(); 
    });
    
    document.getElementById('confirm-delete-btn').addEventListener('click', async e => { 
        await postData('delete-driver', { driver_id: e.target.dataset.driverId }); 
        hideModals(); 
        refreshAllData(); 
    });
      
    // --- REPORTING & ANALYTICS FILTERS ---
    const setupFilterButtons = (containerId, callback) => { 
        document.getElementById(containerId).addEventListener('click', e => { 
            if (e.target.matches('.analytics-filter-btn')) { 
                document.querySelectorAll(`#${containerId} .analytics-filter-btn`).forEach(btn => btn.classList.remove('active-filter')); 
                e.target.classList.add('active-filter'); 
                const period = `period=${e.target.dataset.period}`; 
                callback(period); 
            } 
        }); 
    };
    
    setupFilterButtons('analytics-period-btns', params => { currentAnalyticsParams = params; updateAnalytics(); });
    setupFilterButtons('report-period-btns', params => { currentReportParams = params; });
    
    document.getElementById('custom-range-btn').addEventListener('click', () => { 
        const start = document.getElementById('start-date-input').value; 
        const end = document.getElementById('end-date-input').value; 
        if (start && end) { 
            currentAnalyticsParams = `start_date=${start}&end_date=${end}`; 
            updateAnalytics(); 
        } 
    });
    
    document.getElementById('report-custom-range-btn').addEventListener('click', () => { 
        const start = document.getElementById('report-start-date').value; 
        const end = document.getElementById('report-end-date').value; 
        if (start && end) { 
            currentReportParams = `start_date=${start}&end_date=${end}`; 
        } 
    });
    
    document.getElementById('export-pdf-btn').addEventListener('click', () => { 
        window.location.href = `${API_BASE_URL}/export-report?format=pdf&${currentReportParams}`; 
    });
    
    document.getElementById('export-excel-btn').addEventListener('click', () => { 
        window.location.href = `${API_BASE_URL}/export-report?format=excel&${currentReportParams}`; 
    });

      // --- DATA RENDERING FUNCTIONS ---
      const updateBadges = (stats, unreadCount) => {
          if (stats) {
              const driversBadge = document.getElementById('drivers-badge');
              driversBadge.textContent = stats.drivers_online;
              driversBadge.classList.toggle('hidden', stats.drivers_online === 0);

              const pendingBadge = document.getElementById('pending-requests-badge');
              pendingBadge.textContent = stats.pending_requests;
              pendingBadge.classList.toggle('hidden', stats.pending_requests === 0);

              const activeBadge = document.getElementById('active-rides-badge');
              activeBadge.textContent = stats.active_rides;
              activeBadge.classList.toggle('hidden', stats.active_rides === 0);

              // Update support tickets badge
              const ticketsBadge = document.getElementById('tickets-badge');
              if (ticketsBadge) {
                  ticketsBadge.textContent = stats.open_tickets || 0;
                  ticketsBadge.classList.toggle('hidden', (stats.open_tickets || 0) === 0);
              }
          }

          if (unreadCount !== undefined) {
              const inboxBadge = document.getElementById('inbox-badge');
              inboxBadge.textContent = unreadCount;
              inboxBadge.classList.toggle('hidden', unreadCount === 0);
          }
      };
      const updateDashboardStats = stats => { 
          if (stats) { 
              // Update main stats with animation
              const statMappings = {
                  'stat-revenue': { value: stats.total_revenue, suffix: ' ETB' },
                  'stat-rides': { value: stats.total_rides, suffix: '' },
                  'stat-users': { value: stats.total_passengers, suffix: '' },
                  'stat-drivers': { value: stats.total_drivers, suffix: '' },
                  'stat-completed': { value: stats.completed_rides, suffix: '' },
                  'stat-active': { value: stats.active_rides, suffix: '' },
                  'stat-today-revenue': { value: stats.today_revenue, suffix: ' ETB' },
                  'stat-pending': { value: stats.pending_requests, suffix: '' },
                  'stat-open-tickets': { value: stats.open_tickets || 0, suffix: '' }
              };
              
              Object.entries(statMappings).forEach(([id, config]) => {
                  const el = document.getElementById(id);
                  if (el) {
                      // Animate the number change
                      animateNumber(el, config.value, config.suffix);
                  }
              });
              
              if(stats.pending_requests > lastPendingCount) { 
                  playNotificationSound(); 
              } 
              lastPendingCount = stats.pending_requests; 
              // Update notification badge with unread notification count
              const unreadCount = recentNotifications.length;
              const badge = document.getElementById('notification-badge');
              badge.textContent = unreadCount > 0 ? unreadCount : stats.pending_requests;
              badge.classList.toggle('hidden', unreadCount === 0 && stats.pending_requests === 0);
              
              // Show badge if there are notifications
              if (unreadCount > 0) {
                  badge.classList.remove('hidden');
              } 
          } 
      };
      
      // Animate number changes
      const animateNumber = (element, targetValue, suffix = '') => {
          const startValue = parseFloat(element.textContent.replace(/[^\d.-]/g, '')) || 0;
          const duration = 1000; // 1 second
          const startTime = performance.now();
          
          const animate = (currentTime) => {
              const elapsed = currentTime - startTime;
              const progress = Math.min(elapsed / duration, 1);
              
              // Easing function for smooth animation
              const easeOutQuart = 1 - Math.pow(1 - progress, 4);
              const currentValue = startValue + (targetValue - startValue) * easeOutQuart;
              
              element.textContent = Math.round(currentValue) + suffix;
              
              if (progress < 1) {
                  requestAnimationFrame(animate);
              }
          };
          
          requestAnimationFrame(animate);
      };
      const updateAnalytics = async () => { 
          console.log('updateAnalytics called with params:', currentAnalyticsParams);
          
          // Add loading animation
          const chartContainers = document.querySelectorAll('.chart-container');
          chartContainers.forEach(container => container.classList.add('loading'));
          
          const data = await fetchData('analytics-data', currentAnalyticsParams); 
          console.log('Analytics data received:', data);
          
          if(data) { 
              const {kpis, charts, performance} = data;
              console.log('KPI data:', kpis);
              console.log('Charts data:', charts);
              console.log('Performance data:', performance); 
              
              // Animate KPI updates
              animateNumber(document.getElementById('kpi-rides-completed'), kpis.rides_completed);
              animateNumber(document.getElementById('kpi-active-rides-now'), kpis.active_rides_now);
              animateNumber(document.getElementById('kpi-rides-canceled'), kpis.rides_canceled);
              animateNumber(document.getElementById('kpi-total-revenue'), kpis.total_revenue, ' ETB');
              animateNumber(document.getElementById('kpi-avg-fare'), kpis.avg_fare, ' ETB');
              
              // Update performance metrics
              console.log('Updating performance metrics:', {
                  avg_fare: kpis.avg_fare,
                  completion_rate: kpis.completion_rate,
                  avg_rating: kpis.avg_rating
              });
              
              const avgFareEl = document.getElementById('avg-fare');
              const completionRateEl = document.getElementById('completion-rate');
              const avgRatingEl = document.getElementById('avg-rating');
              
              console.log('Performance metric elements:', {
                  avgFareEl,
                  completionRateEl,
                  avgRatingEl
              });
              
              if (avgFareEl) animateNumber(avgFareEl, kpis.avg_fare, ' ETB');
              if (completionRateEl) animateNumber(completionRateEl, kpis.completion_rate, '%');
              if (avgRatingEl) animateNumber(avgRatingEl, kpis.avg_rating, '/5');
              
              const updateTrend = (elId, val) => { 
                  const el = document.getElementById(elId); 
                  el.textContent = `${val >= 0 ? '↑' : '↓'} ${Math.abs(val)}%`; 
                  el.className = `kpi-trend ${val >= 0 ? 'trend-up' : 'trend-down'}`; 
                  el.style.animation = 'fadeIn 0.5s ease-out';
              }; 
              updateTrend('kpi-rides-trend', kpis.trends.rides); 
              updateTrend('kpi-revenue-trend', kpis.trends.revenue); 
              
              const createChart = (ctxId, chartVar, type, data, options) => { 
                  console.log(`=== Creating Chart: ${ctxId} ===`);
                  console.log('Chart.js available:', typeof Chart !== 'undefined');
                  console.log('Chart data:', data);
                  console.log('Chart options:', options);
                  
                  if (typeof Chart === 'undefined') {
                      console.error('Chart.js is not loaded!');
                      return;
                  }
                  
                  const canvas = document.getElementById(ctxId);
                  if (!canvas) {
                      console.warn(`Canvas element with id '${ctxId}' not found`);
                      return;
                  }
                  
                  console.log(`Canvas found: ${ctxId}`, canvas);
                  const ctx = canvas.getContext('2d'); 
                  
                  if(window[chartVar]) {
                      console.log(`Destroying existing chart: ${chartVar}`);
                      window[chartVar].destroy(); 
                  }
                  
                  try {
                      window[chartVar] = new Chart(ctx, { type, data, options }); 
                      console.log(`✅ Chart created successfully: ${chartVar}`);
                      console.log('Chart instance:', window[chartVar]);
                  } catch (error) {
                      console.error(`❌ Error creating chart ${chartVar}:`, error);
                      console.error('Error details:', error.message, error.stack);
                  }
              }; 
              
              const commonOptions = { 
                  responsive: true, 
                  maintainAspectRatio: false, 
                  plugins: { 
                      legend: { 
                          labels: { 
                              color: getComputedStyle(document.documentElement).getPropertyValue('--text-primary') || '#374151'
                          } 
                      } 
                  } 
              }; 
              
              // Revenue Chart
              console.log('Creating revenue chart with data:', charts.revenue_over_time);
              if (charts.revenue_over_time && charts.revenue_over_time.labels && charts.revenue_over_time.labels.length > 0) {
                  console.log('Revenue chart labels:', charts.revenue_over_time.labels);
                  console.log('Revenue chart data:', charts.revenue_over_time.data);
                  createChart('revenue-over-time-chart', 'revenueChart', 'bar', { 
                      labels: charts.revenue_over_time.labels, 
                      datasets: [{ 
                          label: 'Daily Revenue (ETB)', 
                          data: charts.revenue_over_time.data, 
                          backgroundColor: '#8B5CF6',
                          borderColor: '#7C3AED',
                          borderWidth: 1
                      }] 
                  }, { 
                      ...commonOptions, 
                      scales: { 
                          y: { 
                              beginAtZero: true, 
                              ticks: { 
                                  color: getComputedStyle(document.documentElement).getPropertyValue('--text-primary') || '#374151'
                              } 
                          }, 
                          x: { 
                              ticks: { 
                                  color: getComputedStyle(document.documentElement).getPropertyValue('--text-primary') || '#374151'
                              } 
                          } 
                      } 
                  }); 
              } else {
                  console.warn('Revenue chart data not available or empty:', charts.revenue_over_time);
                  // Show "No data" message in the chart container
                  const chartContainer = document.getElementById('revenue-over-time-chart').parentElement;
                  chartContainer.innerHTML = '<div class="flex items-center justify-center h-full text-gray-500">No revenue data available</div>';
              }
              
              // Vehicle Distribution Chart
              if (charts.vehicle_distribution && Object.keys(charts.vehicle_distribution).length > 0) {
                  createChart('vehicle-dist-chart', 'vehicleDistChart', 'doughnut', { 
                      labels: Object.keys(charts.vehicle_distribution), 
                      datasets: [{ 
                          data: Object.values(charts.vehicle_distribution), 
                          backgroundColor: ['#F59E0B', '#3B82F6', '#10B981', '#EF4444', '#8B5CF6']
                      }] 
                  }, commonOptions); 
              } else {
                  console.warn('Vehicle distribution data not available:', charts.vehicle_distribution);
                  const chartContainer = document.getElementById('vehicle-dist-chart').parentElement;
                  chartContainer.innerHTML = '<div class="flex items-center justify-center h-full text-gray-500">No vehicle data available</div>';
              }
              
              // Payment Method Distribution Chart
              if (charts.payment_method_distribution && Object.keys(charts.payment_method_distribution).length > 0) {
                  createChart('payment-dist-chart', 'paymentDistChart', 'doughnut', { 
                      labels: Object.keys(charts.payment_method_distribution), 
                      datasets: [{ 
                          data: Object.values(charts.payment_method_distribution), 
                          backgroundColor: ['#10B981', '#8B5CF6', '#EF4444', '#F59E0B']
                      }] 
                  }, commonOptions); 
              } else {
                  console.warn('Payment method distribution data not available:', charts.payment_method_distribution);
                  const chartContainer = document.getElementById('payment-dist-chart').parentElement;
                  chartContainer.innerHTML = '<div class="flex items-center justify-center h-full text-gray-500">No payment data available</div>';
              }
              
              // Ride Status Distribution Chart (removed from simple analytics) 
              
              const topDriversList = document.getElementById('top-drivers-list'); 
              topDriversList.innerHTML = ''; 
              
              if (performance.top_drivers && performance.top_drivers.length > 0) {
                  performance.top_drivers.forEach((d, index) => { 
                      const div = document.createElement('div'); 
                      div.className = 'top-driver-item animate-slide-in cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 p-3 rounded-lg transition-colors';
                      div.style.animationDelay = `${index * 0.1}s`;
                      div.title = 'Click to view driver details';
                      
                      // Only make clickable if driver has a real ID (not fake data)
                      if (d.id && d.id > 0) {
                          div.onclick = () => showDriverDetailsFromAnalytics(d.id);
                      } else {
                          div.onclick = () => console.log('This is sample data - no real driver details available');
                          div.title = 'Sample data - no real driver details available';
                          div.style.cursor = 'not-allowed';
                          div.style.opacity = '0.7';
                      }
                      
                      div.innerHTML = `
                          <div class="flex items-center justify-between">
                              <div class="flex items-center">
                                  <img src="/${d.avatar}" class="driver-avatar h-10 w-10 rounded-full mr-4 object-cover" onerror="this.src='/static/img/default_avatar.png'">
                                  <div class="driver-info">
                                      <p class="driver-name font-semibold">${d.name}</p>
                                      <p class="driver-rating text-sm text-gray-500">${d.avg_rating} ⭐</p>
                                  </div>
                              </div>
                              <div class="driver-stats text-right">
                                  <p class="rides-count font-bold text-lg">${d.completed_rides}</p>
                                  <p class="rides-label text-xs text-gray-500">rides</p>
                              </div>
                          </div>
                      `; 
                      topDriversList.appendChild(div); 
                  });
              } else {
                  topDriversList.innerHTML = `
                      <div class="text-center py-8">
                          <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                          </svg>
                          <h3 class="text-lg font-semibold text-gray-600 mb-2">No Driver Performance Data</h3>
                          <p class="text-gray-500">Driver performance data will appear here once drivers complete rides and receive ratings.</p>
                      </div>
                  `;
              } 
              
              // Test Chart.js with a simple chart if no data
              if (!charts.revenue_over_time || !charts.revenue_over_time.labels || charts.revenue_over_time.labels.length === 0) {
                  console.log('Creating test chart to verify Chart.js is working...');
                  const testCanvas = document.getElementById('revenue-over-time-chart');
                  if (testCanvas) {
                      const testCtx = testCanvas.getContext('2d');
                      try {
                          new Chart(testCtx, {
                              type: 'bar',
                              data: {
                                  labels: ['Test'],
                                  datasets: [{
                                      label: 'Test Data',
                                      data: [1],
                                      backgroundColor: '#8B5CF6'
                                  }]
                              },
                              options: {
                                  responsive: true,
                                  maintainAspectRatio: false,
                                  plugins: {
                                      title: {
                                          display: true,
                                          text: 'Chart.js Test - No Real Data Available'
                                      }
                                  }
                              }
                          });
                          console.log('✅ Test chart created successfully');
                      } catch (error) {
                          console.error('❌ Test chart failed:', error);
                      }
                  }
              }
              
              // Remove loading animation
              chartContainers.forEach(container => container.classList.remove('loading'));
          }
      };
      
      // Store selected drivers to preserve selection during re-renders
      const pendingRideSelectedDrivers = {};

      const renderPendingRides = (rides, availableDrivers, containerId) => {
          const list = document.getElementById(containerId);
          
          // Store current selections before clearing
          if (list) {
              const selects = list.querySelectorAll('select[id^="driver-select-"]');
              selects.forEach(select => {
                  const rideId = select.id.replace('driver-select-', '');
                  if (select.value && select.value !== '') {
                      pendingRideSelectedDrivers[rideId] = select.value;
                  }
              });
          }
          
          list.innerHTML = '';
           if (!rides || rides.length === 0) {
              list.innerHTML = `<p class="text-gray-500 text-sm p-4 text-center">No pending rides at the moment.</p>`;
              return;
          }

          rides.forEach(ride => {
              const rideEl = document.createElement('div');
              rideEl.className = 'border-b border-[--border-color] pb-3 p-3';
              rideEl.dataset.rideId = ride.id;

              const filteredDrivers = availableDrivers.filter(d => d.vehicle_type === ride.vehicle_type && d.status === 'Available');
              
              // Get previously selected driver for this ride
              const previouslySelected = pendingRideSelectedDrivers[ride.id];
              
              const driverOptions = filteredDrivers.length > 0
                  ? filteredDrivers.map(d => `<option value="${d.id}" ${d.id == previouslySelected ? 'selected' : ''}>${d.name}</option>`).join('')
                  : '<option disabled>No available drivers</option>';

              rideEl.innerHTML = `
                  <div class="flex justify-between items-start">
                      <p class="font-bold text-sm">${ride.user_name} <span class="font-normal text-xs text-secondary">(${ride.user_phone})</span></p>
                      <span class="font-bold text-sm text-[--chart-purple]">${ride.vehicle_type}</span>
                  </div>
                  <div class="mt-2 text-xs space-y-1 text-secondary">
                      <p><span class="font-semibold text-[--text-primary]">From:</span> ${ride.pickup_address || 'N/A'}</p>
                      <p><span class="font-semibold text-[--text-primary]">To:</span> ${ride.dest_address}</p>
                      <p class="text-xs text-indigo-600 font-medium">Note: ${ride.note || 'None'}</p>
                      <p class="text-xs font-semibold">Time: ${ride.request_time}</p>
                  </div>
                  <div class="mt-2 flex items-center">
                      <select id="driver-select-${ride.id}" class="p-1 border rounded text-xs w-full">${driverOptions}</select>
                      <button class="assign-ride-btn ml-2 px-3 py-1 bg-blue-500 text-white text-xs rounded" data-ride-id="${ride.id}" ${filteredDrivers.length === 0 ? 'disabled' : ''}>Assign</button>
                  </div>`;
              list.appendChild(rideEl);
          });
      };

      const updateDriversTable = () => { const searchTerm = document.getElementById('driver-search-input').value.toLowerCase(); const statusFilter = document.getElementById('driver-status-filter').value; const filtered = allDrivers.filter(d => (d.name.toLowerCase().includes(searchTerm) || d.phone_number.includes(searchTerm) || (d.driver_uid && d.driver_uid.toLowerCase().includes(searchTerm))) && (statusFilter === 'All' || d.status === statusFilter)); const tbody = document.getElementById('drivers-table-body'); tbody.innerHTML = ''; if (!filtered.length) { tbody.innerHTML = '<tr><td colspan="8" class="text-center p-4">No drivers found.</td></tr>'; return; } filtered.forEach(d => { const row = tbody.insertRow(); const blockedBadge = d.is_blocked ? '<span class="ml-2 px-2 py-1 text-xs bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200 rounded">BLOCKED</span>' : ''; const blockBtn = d.is_blocked ? `<button class="action-btn text-green-600" onclick="unblockUser(${d.id}, 'driver', '${d.name}')" title="Unblock">🔓</button>` : `<button class="action-btn text-red-600" onclick="blockUser(${d.id}, 'driver', '${d.name}')" title="Block">🔒</button>`; row.innerHTML = `<td class="p-2 font-mono text-xs">${d.driver_uid||'N/A'}</td><td class="flex items-center"><img src="/${d.profile_picture}" class="h-8 w-8 rounded-full mr-3 object-cover" onerror="this.src='/static/img/default_avatar.png'"><span class="cursor-pointer hover:text-blue-600" onclick="showDriverDetails(${d.id})">${d.name}</span>${blockedBadge}</td><td><a href="tel:${d.phone_number}" class="text-blue-500">${d.phone_number}</a></td><td>${d.vehicle_type}</td><td><select class="driver-status-select status-select-${d.status.replace(' ','-')}" data-driver-id="${d.id}">${['Available','On Trip','Offline'].map(s => `<option value="${s}" ${d.status===s?'selected':''}>${s}</option>`).join('')}</select></td><td>${d.avg_rating.toFixed(1)} ★</td><td class="space-x-2"><button class="action-btn view" data-driver-id="${d.id}" title="View Details">👁️</button><button class="action-btn edit" data-driver-id="${d.id}" title="Edit">✏️</button><button class="action-btn delete" data-driver-id="${d.id}" title="Delete">🗑️</button>${blockBtn}</td>`; }); };
      
      const updatePassengersTable = () => {
          const searchTerm = document.getElementById('passenger-search-input').value.toLowerCase();
          const filtered = allPassengers.filter(p =>
              p.username.toLowerCase().includes(searchTerm) ||
              p.phone_number.includes(searchTerm) ||
              (p.passenger_uid && p.passenger_uid.toLowerCase().includes(searchTerm))
          );
          const tbody = document.getElementById('passengers-table-body');
          tbody.innerHTML = '';
          if (!filtered.length) {
              tbody.innerHTML = '<tr><td colspan="6" class="text-center p-4">No passengers found.</td></tr>';
              return;
          }
          filtered.forEach(p => {
              const row = tbody.insertRow();
              const blockedBadge = p.is_blocked ? '<span class="ml-2 px-2 py-1 text-xs bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200 rounded">BLOCKED</span>' : '';
              const blockBtn = p.is_blocked 
                  ? `<button class="action-btn text-green-600" onclick="unblockUser(${p.id}, 'passenger', '${p.username}')" title="Unblock">🔓</button>`
                  : `<button class="action-btn text-red-600" onclick="blockUser(${p.id}, 'passenger', '${p.username}')" title="Block">🔒</button>`;
              
              row.innerHTML = `
                  <td class="p-2 font-mono text-xs">${p.passenger_uid || 'N/A'}</td>
                  <td class="p-2 flex items-center">
                      <img src="/${p.profile_picture}" class="h-8 w-8 rounded-full mr-3 object-cover" onerror="this.src='/static/img/default_avatar.png'">
                      <span class="cursor-pointer hover:text-blue-600" onclick="showPassengerDetails(${p.id})">${p.username}</span>
                      ${blockedBadge}
                  </td>
                  <td><a href="tel:${p.phone_number}" class="text-blue-500">${p.phone_number}</a></td>
                  <td>${p.rides_taken}</td>
                  <td>${p.join_date}</td>
                  <td class="space-x-2">
                      <button class="action-btn view view-passenger-btn" data-passenger-id="${p.id}" title="View Details">👁️</button>
                      ${blockBtn}
                  </td>
              `;
          });
      };

      const updateActiveRidesTable = (rides) => { const tbody = document.getElementById('active-rides-table-body'); tbody.innerHTML = ''; if (!rides?.length) { tbody.innerHTML = '<tr><td colspan="5" class="text-center p-4">No active rides</td></tr>'; return; } rides.forEach(r => { const row = tbody.insertRow(); row.innerHTML = `<td class="p-2">${r.user_name}</td><td>${r.driver_name}</td><td class="text-xs max-w-xs truncate">${r.dest_address}</td><td><span class="status-badge status-${r.status.replace(' ','-')}">${r.status}</span></td><td class="space-x-2"><button class="px-3 py-1 bg-green-500 text-white text-xs rounded complete-ride-btn" data-ride-id="${r.id}">Complete</button><button class="px-3 py-1 bg-yellow-500 text-white text-xs rounded reassign-ride-btn" data-ride-id="${r.id}">Re-assign</button></td>`; }); };
      const updateRideHistoryTable = () => { const tbody = document.getElementById('rides-history-table-body'); tbody.innerHTML = ''; if (!allRidesHistory?.length) { tbody.innerHTML = '<tr><td colspan="8" class="text-center p-4">No ride history.</td></tr>'; return; } const search = document.getElementById('ride-history-search').value.toLowerCase(); const filtered = allRidesHistory.filter(r => r.user_name.toLowerCase().includes(search) || r.driver_name?.toLowerCase().includes(search)); const pageInfo = document.getElementById('ride-history-page-info'); const totalPages = Math.ceil(filtered.length / RIDES_PER_PAGE); rideHistoryPage = Math.min(rideHistoryPage, totalPages) || 1; pageInfo.textContent = `Page ${rideHistoryPage} of ${totalPages}`; const paginated = filtered.slice((rideHistoryPage - 1) * RIDES_PER_PAGE, rideHistoryPage * RIDES_PER_PAGE); paginated.forEach(r => { const row = tbody.insertRow(); row.innerHTML = `<td class="p-2">${r.id}</td><td>${r.user_name}</td><td>${r.driver_name}</td><td>${r.fare} ETB</td><td><span class="status-badge status-${r.status}">${r.status}</span></td><td>${r.rating ? '★'.repeat(r.rating) : 'N/A'}</td><td>${r.request_time}</td><td><button class="action-btn view view-ride-btn" data-ride-id="${r.id}">👁️</button></td>`; }); };
      const refreshFeedback = async () => { allFeedback = await fetchData('all-feedback') || []; const list = document.getElementById('feedback-list'); list.innerHTML = ''; if(!allFeedback.length) { list.innerHTML = '<p class="text-secondary text-center">No feedback yet.</p>'; return; } allFeedback.forEach(f => { const item = document.createElement('div'); item.className = `border-b pb-3 ${f.is_resolved ? 'opacity-50' : ''}`; item.innerHTML = `<div class="flex justify-between items-center"><p class="font-semibold">Ride #${f.ride_id} - ${f.passenger_name}</p><span class="text-xs text-secondary">${f.date}</span></div><div class="flex items-center mt-1"><span class="text-yellow-500">${f.rating ? '★'.repeat(f.rating) : ''}</span><p class="ml-2 text-sm italic">"${f.comment || 'No comment'}"</p></div><div class="flex justify-between items-center mt-1"><p class="text-xs text-secondary">Driver: ${f.driver_name}</p>${!f.is_resolved ? `<button data-id="${f.id}" class="resolve-feedback-btn px-2 py-1 text-xs bg-green-500 text-white rounded">Mark as Resolved</button>`: '<span class="text-xs text-green-600 font-semibold">Resolved</span>'}</div>`; list.appendChild(item); }); };
      
      const refreshSupportTickets = async () => { 
          const tickets = await fetchData('support-tickets') || []; 
          const list = document.getElementById('support-tickets-list'); 
          list.innerHTML = ''; 
          
          // Get ride history for context
          const rideHistory = await fetchData('all-rides-data') || [];
          
          // Calculate ticket statistics
          const totalTickets = tickets.length;
          const openTickets = tickets.filter(t => t.status === 'Open').length;
          const inProgressTickets = tickets.filter(t => t.status === 'In Progress').length;
          const resolvedTickets = tickets.filter(t => t.status === 'Resolved').length;
          
          // Update support stats
          const totalTicketsEl = document.getElementById('total-tickets');
          const openTicketsEl = document.getElementById('open-tickets');
          const inProgressTicketsEl = document.getElementById('in-progress-tickets');
          const resolvedTicketsEl = document.getElementById('resolved-tickets');
          
          if (totalTicketsEl) animateNumber(totalTicketsEl, totalTickets);
          if (openTicketsEl) animateNumber(openTicketsEl, openTickets);
          if (inProgressTicketsEl) animateNumber(inProgressTicketsEl, inProgressTickets);
          if (resolvedTicketsEl) animateNumber(resolvedTicketsEl, resolvedTickets);
          
          // Update tickets badge
          const ticketsBadge = document.getElementById('tickets-badge');
          if (ticketsBadge) {
              ticketsBadge.textContent = openTickets;
              ticketsBadge.classList.toggle('hidden', openTickets === 0);
          }
          
          if(!tickets.length) { 
              list.innerHTML = '<p class="text-gray-500 text-center">No support tickets yet.</p>'; 
              return; 
          } 
          
          tickets.forEach(ticket => { 
              const item = document.createElement('div'); 
              const statusColors = {
                  'Open': 'bg-red-100 text-red-800',
                  'In Progress': 'bg-yellow-100 text-yellow-800',
                  'Resolved': 'bg-green-100 text-green-800',
                  'Closed': 'bg-gray-100 text-gray-800'
              };
              
              // Find ride details for context
              const rideDetails = ticket.ride_id ? rideHistory.find(r => r.id === ticket.ride_id) : null;
              
              item.className = `border border-gray-200 dark:border-gray-700 rounded-lg p-4 ${ticket.status === 'Resolved' ? 'opacity-60' : ''}`;
              item.innerHTML = `
                  <div class="flex justify-between items-start mb-2">
                      <div>
                          <button class="font-semibold text-gray-900 dark:text-white hover:text-blue-600 underline" onclick="viewPassengerDetailsFromTicket('${ticket.passenger_name}')" title="View passenger details">
                              ${ticket.passenger_name}
                          </button>
                          <p class="text-xs text-gray-500">${ticket.passenger_phone}</p>
                      </div>
                      <span class="px-2 py-1 text-xs rounded-full ${statusColors[ticket.status] || 'bg-gray-100'}">${ticket.status}</span>
                  </div>
                  <div class="mb-3">
                      <div class="flex items-center justify-between">
                          <span class="text-sm font-bold text-red-600 bg-red-50 dark:bg-red-900/20 px-2 py-1 rounded">${ticket.feedback_type}</span>
                          ${ticket.ride_id ? `
                              <button class="text-sm text-blue-600 hover:text-blue-800 font-medium underline" onclick="viewRideDetailsFromTicket(${ticket.ride_id})" title="View ride details">
                                  Ride #${ticket.ride_id}
                              </button>
                          ` : ''}
                      </div>
                  </div>
                  <p class="text-sm text-gray-700 dark:text-gray-300 mb-2">${ticket.details}</p>
                  <div class="flex justify-between items-center text-xs text-gray-500">
                      <span>${ticket.created_at}</span>
                      ${ticket.status !== 'Resolved' ? `<button class="resolve-ticket-btn px-3 py-1 bg-green-600 text-white rounded hover:bg-green-700" data-ticket-id="${ticket.id}">Resolve</button>` : ''}
                  </div>
                  ${ticket.admin_response ? `<div class="mt-2 pt-2 border-t border-gray-200"><p class="text-xs text-gray-600"><strong>Response:</strong> ${ticket.admin_response}</p></div>` : ''}
              `; 
              list.appendChild(item); 
          }); 
      };

      // View ride details from support ticket
      window.viewRideDetailsFromTicket = async (rideId) => {
          try {
              const data = await fetchData(`ride-details/${rideId}`);
              if (data) {
                  showRideDetails(data);
              } else {
                  alert('Ride details not found');
              }
          } catch (error) {
              console.error('Error loading ride details:', error);
              alert('Error loading ride details');
          }
      };

      // View passenger ride history from support ticket
      window.viewPassengerRideHistory = (passengerName) => {
          // Switch to ride history pane and filter by passenger name
          showPane('ride-history');
          setTimeout(() => {
              const searchInput = document.getElementById('ride-history-search');
              if (searchInput) {
                  searchInput.value = passengerName;
                  // Trigger the search
                  const event = new Event('input', { bubbles: true });
                  searchInput.dispatchEvent(event);
              }
          }, 100);
      };

      // View passenger details from support ticket
      window.viewPassengerDetailsFromTicket = async (passengerName) => {
          try {
              // Find passenger by name in the passengers list
              const passengers = await fetchData('passengers') || [];
              const passenger = passengers.find(p => p.username === passengerName);
              
              if (passenger) {
                  const data = await fetchData(`passenger-details/${passenger.id}`);
                  if (data) {
                      showPassengerDetails(data);
                  } else {
                      alert('Passenger details not found');
                  }
              } else {
                  alert('Passenger not found');
              }
          } catch (error) {
              console.error('Error loading passenger details:', error);
              alert('Error loading passenger details');
          }
      };
      
      const renderNotifications = () => {
          const dropdown = document.getElementById('notification-dropdown');
          dropdown.innerHTML = '';
          
          // Add some test notifications if none exist
          if (recentNotifications.length === 0) {
              recentNotifications = [
                  'New ride request from John Doe',
                  'Driver Ahmed completed a ride',
                  'Payment received for ride #1234',
                  'New driver registered: Maria'
              ];
          }
          
          if (recentNotifications.length === 0) {
              dropdown.innerHTML = '<p class="p-4 text-sm text-center text-[--text-secondary]">No new notifications</p>';
              return;
          }
          // Add header
          const header = document.createElement('div');
          header.className = 'p-3 border-b border-[--border-color] bg-[--main-bg]';
          header.innerHTML = '<h3 class="text-sm font-semibold text-[--text-primary]">Notifications</h3>';
          dropdown.appendChild(header);
          
          recentNotifications.forEach((notif, index) => {
              const item = document.createElement('div');
              item.className = 'notification-item p-3 border-b border-[--border-color] text-sm cursor-pointer hover:bg-[--main-bg]';
              item.textContent = notif;
              item.addEventListener('click', () => {
                  // Mark this notification as read by removing it
                  recentNotifications.splice(index, 1);
                  renderNotifications();
                  // Update badge
                  const badge = document.getElementById('notification-badge');
                  badge.textContent = recentNotifications.length;
                  badge.classList.toggle('hidden', recentNotifications.length === 0);
                  // Close dropdown if no more notifications
                  if(recentNotifications.length === 0) {
                      dropdown.classList.add('hidden');
                  }
              });
              dropdown.appendChild(item);
          });
          
          // Add "Clear All" button if there are notifications
          if(recentNotifications.length > 0) {
              const clearBtn = document.createElement('button');
              clearBtn.className = 'w-full p-2 text-xs text-center text-blue-600 hover:bg-[--main-bg] font-semibold border-t border-[--border-color]';
              clearBtn.textContent = 'Clear All';
              clearBtn.addEventListener('click', () => {
                  recentNotifications.length = 0;
                  renderNotifications();
                  const badge = document.getElementById('notification-badge');
                  badge.classList.add('hidden');
                  dropdown.classList.add('hidden');
              });
              dropdown.appendChild(clearBtn);
          }
      };

      // --- EVENT LISTENERS ---
      document.getElementById('notification-bell').addEventListener('click', (e) => { 
          e.stopPropagation(); 
          const dropdown = document.getElementById('notification-dropdown'); 
          const badge = document.getElementById('notification-badge');
          
          console.log('Notification bell clicked');
          console.log('Dropdown classes:', dropdown.classList.toString());
          console.log('Recent notifications:', recentNotifications);
          
          dropdown.classList.toggle('hidden'); 
          if(!dropdown.classList.contains('hidden')) { 
              renderNotifications(); 
              // Only hide badge if there are actual notifications to show
              if(recentNotifications.length > 0) {
                  badge.classList.add('hidden');
              }
          } 
      });
      document.addEventListener('click', (e) => { const dropdown = document.getElementById('notification-dropdown'); const bell = document.getElementById('notification-bell'); if (!dropdown.classList.contains('hidden') && !bell.contains(e.target)) { dropdown.classList.add('hidden'); } });
      const setupAssignmentListeners = (containerId) => { 
          const container = document.getElementById(containerId);
          if (container) {
              container.addEventListener('click', async (e) => { 
                  if (e.target.classList.contains('assign-ride-btn')) { 
                      const rideId = e.target.dataset.rideId; 
                      const driverSelect = document.getElementById(`driver-select-${rideId}`);
                      if (driverSelect) {
                          const driverId = driverSelect.value; 
                          if (driverId && driverId !== '') { 
                              const result = await postData('assign-ride', { ride_id: rideId, driver_id: driverId }); 
                              
                              // Clear the selected driver for this ride since it's now assigned
                              delete pendingRideSelectedDrivers[rideId];
                              
                              refreshAllData(); 
                          } else { 
                              alert('Please select a driver.'); 
                          } 
                      } else {
                          console.error(`Driver select element not found for ride ${rideId}`);
                      }
                  } 
              }); 
          }
      };
      setupAssignmentListeners('pending-rides-summary-list');
      setupAssignmentListeners('pending-rides-container');

      document.getElementById('drivers-table-body').addEventListener('change', async e => { if (e.target.classList.contains('driver-status-select')) { await postData('update-driver-status', { driver_id: e.target.dataset.driverId, status: e.target.value }); refreshAllData(); } });
      document.getElementById('drivers-table-body').addEventListener('click', async e => { const btn = e.target.closest('.action-btn'); if (!btn) return; const id = btn.dataset.driverId; if (btn.classList.contains('view')) { const data = await fetchData(`driver-details/${id}`); if(data) showDriverDetails(data); } else if (btn.classList.contains('edit')) { const driver = await fetchData(`driver/${id}`); if (driver) { const form = document.getElementById('edit-driver-form'); form.reset(); form.elements.id.value = driver.id; form.elements.name.value = driver.name; form.elements.phone_number.value = driver.phone_number; form.elements.vehicle_type.value = driver.vehicle_type; form.elements.vehicle_details.value = driver.vehicle_details; form.elements.vehicle_plate_number.value = driver.vehicle_plate_number; form.elements.license_info.value = driver.license_info; showModal('edit-driver-modal'); } } else if (btn.classList.contains('delete')) { document.getElementById('confirm-delete-btn').dataset.driverId = id; showModal('delete-driver-modal'); } });
      document.getElementById('active-rides-table-body').addEventListener('click', async e => { const id = e.target.dataset.rideId; if (!id) return; if (e.target.classList.contains('complete-ride-btn')) await postData('complete-ride', { ride_id: id }); else if (e.target.classList.contains('reassign-ride-btn')) await postData('cancel-ride', { ride_id: id }); refreshAllData(); });
      document.getElementById('feedback-list').addEventListener('click', async e => { if (e.target.classList.contains('resolve-feedback-btn')) { await postData(`feedback/resolve/${e.target.dataset.id}`, {}); refreshFeedback(); refreshUnreadCount(); } });
      document.getElementById('support-tickets-list').addEventListener('click', async e => { if (e.target.classList.contains('resolve-ticket-btn')) { const ticketId = e.target.dataset.ticketId; const response = prompt('Enter admin response (optional):'); const result = await postData(`support-tickets/${ticketId}/resolve`, { response: response || '' }); if (result && !result.error) { refreshSupportTickets(); } } });
      document.getElementById('settings-form').addEventListener('submit', async e => { e.preventDefault(); await postData('settings', Object.fromEntries(new FormData(e.target))); alert('Settings Saved!'); });
      
      // Commission settings form handler
      document.getElementById('commission-settings-form')?.addEventListener('submit', async (e) => {
          e.preventDefault();
          try {
              const formData = new FormData(e.target);
              const data = {
                  bajaj_rate: parseFloat(formData.get('bajaj_rate')),
                  car_rate: parseFloat(formData.get('car_rate'))
              };
              
              const response = await fetch(`${API_BASE_URL}/commission-settings`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify(data)
              });
              
              const result = await response.json();
              
              if (result.success) {
                  setFeedbackMessage('commission-feedback', 'Commission settings updated successfully!', 'success');
                  hideModals();
              } else {
                  setFeedbackMessage('commission-feedback', result.error || 'Error updating settings', 'error');
              }
          } catch (error) {
              console.error('Error updating commission settings:', error);
              setFeedbackMessage('commission-feedback', 'Error updating settings', 'error');
          }
      });
      document.getElementById('driver-search-input').addEventListener('input', updateDriversTable);
      document.getElementById('passenger-search-input').addEventListener('input', updatePassengersTable);
      document.getElementById('driver-status-filter').addEventListener('change', updateDriversTable);
      document.getElementById('ride-history-search').addEventListener('input', () => { rideHistoryPage = 1; updateRideHistoryTable(); });
      document.getElementById('ride-history-prev').addEventListener('click', () => { if (rideHistoryPage > 1) { rideHistoryPage--; updateRideHistoryTable(); } });
      document.getElementById('ride-history-next').addEventListener('click', () => { rideHistoryPage++; updateRideHistoryTable(); });

      document.getElementById('rides-history-table-body').addEventListener('click', async e => {
          const btn = e.target.closest('.view-ride-btn');
          if (btn) {
              const id = btn.dataset.rideId;
              const data = await fetchData(`ride-details/${id}`);
              if(data) showRideDetails(data);
          }
      });

      document.getElementById('passengers-table-body').addEventListener('click', async e => {
          const btn = e.target.closest('.view-passenger-btn');
          if (btn) {
              const id = btn.dataset.passengerId;
              const data = await fetchData(`passenger-details/${id}`);
              if(data) showPassengerDetails(data);
          }
      });


      // --- DRIVER DETAILS & MAP ---
      const showDriverDetailsFromAnalytics = async (driverId) => {
          try {
              const data = await fetchData(`driver-details/${driverId}`);
              if (data) {
                  showDriverDetails(data);
              } else {
                  console.error('Failed to load driver details');
              }
          } catch (error) {
              console.error('Error loading driver details:', error);
          }
      };

      const showDriverDetails = (data) => { const content = document.getElementById('driver-details-content'); const p = data.profile; const docLink = (path, name) => path ? `<a href="/${path}" target="_blank" class="text-blue-500 hover:underline">${name}</a>` : 'Not Uploaded'; content.innerHTML = `<div class="grid md:grid-cols-3 gap-6"><div class="text-center"><img src="/${p.avatar}" class="rounded-full w-32 h-32 mx-auto border-4 object-cover" onerror="this.src='/static/img/default_avatar.png'"><h3 class="text-xl font-bold mt-4">${p.name}</h3><p class="text-sm font-mono">${p.driver_uid}</p><p class="text-sm">${p.phone_number}</p><span class="status-badge status-${p.status.replace(' ','-')} mt-2 inline-block">${p.status}</span></div><div class="md:col-span-2 space-y-4"><div><h4 class="font-bold border-b pb-1 mb-2">Vehicle & Docs</h4><div class="text-sm space-y-1"><p><strong>Type:</strong> ${p.vehicle_type}</p><p><strong>Details:</strong> ${p.vehicle_details}</p><p><strong>Plate:</strong> ${p.plate_number}</p><p><strong>License:</strong> ${p.license}</p><p><strong>License Doc:</strong> ${docLink(p.license_document, 'View')}</p><p><strong>Vehicle Doc:</strong> ${docLink(p.vehicle_document, 'View')}</p></div></div><div><h4 class="font-bold border-b pb-1 mb-2">Performance</h4><div class="grid grid-cols-2 gap-4 mt-2 text-sm"><div class="card p-3"><p class="font-semibold">Completed Rides</p><p class="text-2xl font-bold">${data.stats.completed_rides}</p></div><div class="card p-3"><p class="font-semibold">Avg. Rating</p><p class="text-2xl font-bold">${data.stats.avg_rating.toFixed(2)} ★</p></div><div class="card p-3"><p class="font-semibold">Weekly Earnings</p><p class="text-2xl font-bold">${data.stats.total_earnings_weekly} ETB</p></div><div class="card p-3"><p class="font-semibold">Total Earnings</p><p class="text-2xl font-bold">${data.stats.total_earnings_all_time} ETB</p></div></div></div></div></div><div class="mt-6"><h4 class="font-bold border-b pb-1 mb-2">Recent History</h4>${data.history.length ? data.history.map(r => `<div class="grid grid-cols-4 text-sm p-2 border-b"><span>#${r.id}</span><span>${r.date}</span><span>${r.fare} ETB</span><span class="status-badge status-${r.status}">${r.status}</span></div>`).join('') : '<p class="text-center p-4">No recent history.</p>'}</div>`; showModal('driver-details-modal'); };
      
      const showPassengerDetails = (data) => {
          const content = document.getElementById('passenger-details-content');
          const p = data.profile;
          content.innerHTML = `
              <div class="grid md:grid-cols-3 gap-6">
                  <div class="text-center">
                      <img src="/${p.avatar}" class="rounded-full w-32 h-32 mx-auto border-4 object-cover" onerror="this.src='/static/img/default_avatar.png'">
                      <h3 class="text-xl font-bold mt-4">${p.name}</h3>
                      <p class="text-sm font-mono text-secondary">${p.passenger_uid}</p>
                      <p class="text-sm">${p.phone_number}</p>
                      <p class="text-xs text-secondary mt-1">Member since ${p.join_date}</p>
                  </div>
                  <div class="md:col-span-2 space-y-4">
                      <div>
                          <h4 class="font-bold border-b pb-1 mb-2">Performance</h4>
                          <div class="grid grid-cols-3 gap-4 mt-2 text-sm">
                              <div class="card p-3 text-center"><p class="font-semibold">Total Rides</p><p class="text-2xl font-bold">${data.stats.total_rides}</p></div>
                              <div class="card p-3 text-center"><p class="font-semibold">Total Spent</p><p class="text-2xl font-bold">${data.stats.total_spent} ETB</p></div>
                              <div class="card p-3 text-center"><p class="font-semibold">Avg. Rating Given</p><p class="text-2xl font-bold">${data.stats.avg_rating_given.toFixed(2)} ★</p></div>
                          </div>
                      </div>
                  </div>
              </div>
              <div class="mt-6">
                  <h4 class="font-bold border-b pb-1 mb-2">Recent Ride History (Up to 20)</h4>
                  <div class="space-y-2">
                  ${data.history.length ? data.history.map(r => `
                      <div class="grid grid-cols-5 gap-2 text-xs p-2 border-b">
                          <span class="col-span-5"><strong class="text-primary">Ride ID: #${r.id}</strong> - ${r.date}</span>
                          <span class="col-span-2"><strong>From:</strong> ${r.pickup_address || 'N/A'}</span>
                          <span class="col-span-3"><strong>To:</strong> ${r.dest_address}</span>
                          <span><strong>Driver:</strong> ${r.driver_name}</span>
                          <span><strong>Fare:</strong> ${r.fare} ETB</span>
                           <span class="text-yellow-500"><strong>Rating:</strong> ${r.rating_given !== 'N/A' ? '★'.repeat(r.rating_given) : 'Not Rated'}</span>
                          <span colspan="2"><span class="status-badge status-${r.status}">${r.status}</span></span>
                      </div>`).join('') : '<p class="text-center text-secondary p-4">No ride history.</p>'}
                  </div>
              </div>`;
          showModal('passenger-details-modal');
      };

      const showRideDetails = async (data) => {
          const content = document.getElementById('ride-details-content');
          const trip = data.trip_info;
          const passenger = data.passenger;
          const driver = data.driver;
          const timestamps = data.timestamps;
          const feedback = data.feedback;

          content.innerHTML = `
              <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
                  <div class="lg:col-span-2">
                      <div id="ride-detail-map" class="w-full h-64 bg-gray-200 rounded-lg border shadow-inner mb-4"></div>
                      <div class="grid grid-cols-2 gap-4 text-sm">
                          <div><strong>From:</strong> ${trip.pickup_address}</div>
                          <div><strong>To:</strong> ${trip.dest_address}</div>
                      </div>
                  </div>
                  <div class="space-y-4 text-sm">
                      <div class="card p-4">
                           <h4 class="font-bold text-md mb-2">Trip Info</h4>
                           <p><strong>ID:</strong> #${trip.id}</p>
                           <p><strong>Status:</strong> <span class="status-badge status-${trip.status}">${trip.status}</span></p>
                           <p><strong>Fare:</strong> ${trip.fare} ETB</p>
                           <p><strong>Distance:</strong> ${trip.distance} km</p>
                           <p><strong>Payment:</strong> ${trip.payment_method}</p>
                      </div>
                       <div class="card p-4">
                           <h4 class="font-bold text-md mb-2">Timestamps</h4>
                           <p><strong>Requested:</strong> ${timestamps.requested}</p>
                           <p><strong>Assigned:</strong> ${timestamps.assigned}</p>
                      </div>
                  </div>
              </div>
               <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
                  <div class="card p-4">
                      <h4 class="font-bold text-md mb-2">Passenger</h4>
                      <div class="flex items-center">
                          <img src="/${passenger.avatar}" class="h-12 w-12 rounded-full object-cover mr-4" onerror="this.src='/static/img/default_user.svg'">
                          <div>
                              <p class="font-semibold">${passenger.name}</p>
                              <p class="text-xs text-secondary">${passenger.phone}</p>
                          </div>
                      </div>
                  </div>
                   <div class="card p-4">
                      <h4 class="font-bold text-md mb-2">Driver</h4>
                      <div class="flex items-center">
                          <img src="/${driver.avatar}" class="h-12 w-12 rounded-full object-cover mr-4" onerror="this.src='/static/img/default_user.svg'">
                          <div>
                              <p class="font-semibold">${driver.name}</p>
                               <p class="text-xs text-secondary">${driver.phone}</p>
                              <p class="text-xs text-secondary">${driver.vehicle}</p>
                          </div>
                      </div>
                  </div>
              </div>
              <div class="card p-4 mt-6">
                  <h4 class="font-bold text-md mb-2">Feedback</h4>
                  ${feedback.rating ? `
                      <div class="flex items-center">
                          <span class="text-yellow-500 text-xl">${'★'.repeat(feedback.rating)}</span>
                          <p class="ml-4 italic">"${feedback.comment || 'No comment provided.'}"</p>
                      </div>
                  ` : '<p class="text-secondary text-sm">No feedback was provided for this ride.</p>'}
              </div>
          `;
          showModal('ride-details-modal');

          // Map has to be initialized AFTER the modal is visible
          const map = L.map('ride-detail-map').setView([trip.pickup_coords.lat, trip.pickup_coords.lon], 15);
          L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
          L.marker([trip.pickup_coords.lat, trip.pickup_coords.lon], {icon: pendingIcon}).addTo(map).bindPopup("Pickup");
          L.marker([trip.dest_coords.lat, trip.dest_coords.lon], {icon: destIcon}).addTo(map).bindPopup("Destination");
          const routeLine = await drawRouteOnMap(trip.pickup_coords, trip.dest_coords);
          if(routeLine) {
              routeLine.addTo(map);
              map.fitBounds(routeLine.getBounds(), {padding: [20, 20]});
          }
           setTimeout(() => map.invalidateSize(), 100);
      };

      async function drawRouteOnMap(pickup, destination, color) {
          const url = `https://router.project-osrm.org/route/v1/driving/${pickup.lon},${pickup.lat};${destination.lon},${destination.lat}?overview=full&geometries=geojson`;
          try {
              const response = await fetch(url, { 
                  timeout: 5000, // 5 second timeout
                  signal: AbortSignal.timeout(5000)
              });
              
              if (!response.ok) {
                  console.warn('Route service unavailable, skipping route drawing');
                  return null;
              }
              
              const data = await response.json();
              if (data.routes?.length) {
                  return L.polyline(data.routes[0].geometry.coordinates.map(c => [c[1], c[0]]), { color: color || getCssVar('--chart-purple'), weight: 5 });
              }
          } catch (error) { 
              // Silently handle network errors - route drawing is optional
              if (error.name === 'AbortError' || error.message.includes('Failed to fetch') || error.message.includes('ERR_NETWORK')) {
                  console.log('Route service unavailable, using straight-line fallback');
                  // Create a simple straight line as fallback
                  return L.polyline([[pickup.lat, pickup.lon], [destination.lat, destination.lon]], { 
                      color: (color || getCssVar('--chart-purple')) + '80', // Add transparency
                      weight: 3,
                      dashArray: '5, 5' // Dashed line to indicate it's not a real route
                  });
              } else {
                  console.warn('Route drawing error:', error.message);
              }
          }
          return null;
      }

      const updateLiveMap = async () => {
          if (!dashboardMap) return;

          // Clear existing ride layers
          Object.values(rideLayers).forEach(layerGroup => dashboardMap.removeLayer(layerGroup));
          rideLayers = {};
          const allBounds = [];

          const processRide = async (ride, isPending) => {
              const pickup = { lat: ride.pickup_lat, lon: ride.pickup_lon };
              const dest = { lat: ride.dest_lat, lon: ride.dest_lon };
              
              const pickupPopup = `<b>${isPending ? 'Request from' : 'Pickup for'}: ${ride.user_name}</b><br>To: ${ride.dest_address}`;
              const destPopup = `<b>Destination for ${ride.user_name}</b>`;
              
              const pickupMarker = L.marker([pickup.lat, pickup.lon], { icon: isPending ? pendingIcon : activeIcon }).bindPopup(pickupPopup);
              const destMarker = L.marker([dest.lat, dest.lon], { icon: destIcon }).bindPopup(destPopup);
              const routeLine = await drawRouteOnMap(pickup, dest, isPending ? getCssVar('--chart-blue') : getCssVar('--chart-red'));
              
              const layerGroup = L.layerGroup([pickupMarker, destMarker]);
              if (routeLine) layerGroup.addLayer(routeLine);
              
              rideLayers[ride.id] = layerGroup;
              allBounds.push([pickup.lat, pickup.lon], [dest.lat, dest.lon]);
          };

          const ridePromises = [
              ...allPendingRides.map(ride => processRide(ride, true)),
              ...allActiveRides.map(ride => processRide(ride, false))
          ];
          await Promise.all(ridePromises);

          // Add all new layers to the map and adjust view
          Object.values(rideLayers).forEach(layerGroup => layerGroup.addTo(dashboardMap));
          if (allBounds.length > 0) {
              dashboardMap.fitBounds(allBounds, { padding: [50, 50], maxZoom: 15 });
          } else {
              dashboardMap.setView([13.88, 39.46], 10); // Center between Mekelle and Adigrat
          }
      };

      // --- ADMIN MANAGEMENT ---
      const refreshAdminUsers = async () => {
          const admins = await fetchData('admins');
          const listEl = document.getElementById('admin-users-list');
          listEl.innerHTML = '';
          if (admins) {
              admins.forEach(admin => {
                  const div = document.createElement('div');
                  div.className = 'flex items-center justify-between p-2 bg-[--main-bg] rounded';
                  div.innerHTML = `<span>${admin.username}</span><button class="action-btn delete delete-admin-btn" data-admin-id="${admin.id}">🗑️</button>`;
                  listEl.appendChild(div);
              });
          }
      };

      const setFeedbackMessage = (elementId, message, isError = false) => {
          const el = document.getElementById(elementId);
          if (!el) {
              console.warn(`Feedback element '${elementId}' not found`);
              return;
          }
          el.textContent = message;
          el.className = `text-sm mt-2 ${isError ? 'text-red-500' : 'text-green-500'}`;
          setTimeout(() => {
              if (el) el.textContent = '';
          }, 4000);
      };

      const getTimeAgo = (dateString) => {
          const now = new Date();
          const date = new Date(dateString);
          const diffInSeconds = Math.floor((now - date) / 1000);
          
          if (diffInSeconds < 60) {
              return `${diffInSeconds} seconds ago`;
          } else if (diffInSeconds < 3600) {
              const minutes = Math.floor(diffInSeconds / 60);
              return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
          } else if (diffInSeconds < 86400) {
              const hours = Math.floor(diffInSeconds / 3600);
              return `${hours} hour${hours > 1 ? 's' : ''} ago`;
          } else {
              const days = Math.floor(diffInSeconds / 86400);
              return `${days} day${days > 1 ? 's' : ''} ago`;
          }
      };

      // Update Profile (separate from password)
      document.getElementById('update-profile-form').addEventListener('submit', async (e) => {
          e.preventDefault();
          const form = e.target;
          const formData = new FormData(form);
          
          const result = await postFormData('admins/update-profile', formData); 
      
          if (result && !result.error) {
              setFeedbackMessage('profile-feedback', 'Profile updated successfully!');
              form.elements.profile_picture.value = '';
              document.getElementById('profile-picture-filename').textContent = 'No file chosen';

              const newUsername = form.elements.username.value;
              const usernameDisplays = document.querySelectorAll('.font-semibold');
              usernameDisplays.forEach(el => {
                  if (el.textContent !== 'Logout') {
                      el.textContent = newUsername.charAt(0).toUpperCase() + newUsername.slice(1);
                  }
              });
      
              if (result.profile_picture) {
                  const newAvatarSrc = `/${result.profile_picture}?v=${new Date().getTime()}`;
                  document.getElementById('sidebar-avatar').src = newAvatarSrc;
                  document.getElementById('settings-avatar').src = newAvatarSrc;
              }
          } else {
              const errorMessage = result ? result.error : 'An unexpected error occurred. Please try again.';
              setFeedbackMessage('profile-feedback', `Error: ${errorMessage}`, true);
          }
      });

      // Change Password Button
      document.getElementById('change-password-btn').addEventListener('click', () => {
          showModal('change-password-modal');
      });

      // Change Password Form
      document.getElementById('change-password-form').addEventListener('submit', async (e) => {
          e.preventDefault();
          
          const currentPassword = document.getElementById('password-current-password').value;
          const newPassword = document.getElementById('password-new-password').value;
          const confirmPassword = document.getElementById('password-confirm-password').value;
          
          // Validate passwords match
          if (newPassword !== confirmPassword) {
              setFeedbackMessage('password-feedback', 'New passwords do not match', true);
              return;
          }
          
          // Validate password length
          if (newPassword.length < 6) {
              setFeedbackMessage('password-feedback', 'Password must be at least 6 characters', true);
              return;
          }
          
          const result = await postData('admins/change-password', {
              current_password: currentPassword,
              new_password: newPassword,
              confirm_password: confirmPassword
          });
          
          if (result && !result.error) {
              setFeedbackMessage('password-feedback', 'Password changed successfully!');
              setTimeout(() => {
                  hideModals();
                  e.target.reset();
              }, 1500);
          } else {
              const errorMessage = result ? result.error : 'Failed to change password';
              setFeedbackMessage('password-feedback', `Error: ${errorMessage}`, true);
          }
      });

      document.getElementById('add-admin-form').addEventListener('submit', async (e) => {
          e.preventDefault();
          const username = document.getElementById('new-admin-username').value;
          const password = document.getElementById('new-admin-password').value;
          const result = await postData('admins/add', { username, password });
          if (result && !result.error) {
              setFeedbackMessage('admin-feedback', 'Admin added successfully!');
              e.target.reset();
              refreshAdminUsers();
          } else {
               setFeedbackMessage('admin-feedback', `Error: ${result.error}`, true);
          }
      });

      // Helper function to show confirm modal
      const showConfirmModal = (title, message, onConfirm) => {
          document.getElementById('confirm-modal-title').textContent = title;
          document.getElementById('confirm-modal-message').textContent = message;
          document.getElementById('confirm-modal-btn').onclick = () => {
              hideModals();
              onConfirm();
          };
          showModal('confirm-modal');
      };

      document.getElementById('admin-users-list').addEventListener('click', async (e) => {
          if (e.target.classList.contains('delete-admin-btn')) {
              const adminId = e.target.dataset.adminId;
              showConfirmModal(
                  'Delete Admin',
                  'Are you sure you want to delete this admin? This action cannot be undone.',
                  async () => {
                  const result = await postData('admins/delete', { admin_id: parseInt(adminId) });
                  if (result && !result.error) {
                      setFeedbackMessage('admin-feedback', 'Admin deleted.');
                      refreshAdminUsers();
                  } else {
                      setFeedbackMessage('admin-feedback', `Error: ${result.error}`, true);
                  }
              }
              );
          }
      });

      // Block/Unblock User Functionality
      document.getElementById('block-user-form').addEventListener('submit', async (e) => {
          e.preventDefault();
          
          const userId = document.getElementById('block-user-id').value;
          const userType = document.getElementById('block-user-type').value;
          const reason = document.getElementById('block-reason').value;
          
          const result = await postData('users/block', {
              user_id: parseInt(userId),
              user_type: userType,
              reason: reason
          });
          
          if (result && !result.error) {
              setFeedbackMessage('block-feedback', 'User blocked successfully!');
              setTimeout(() => {
                  hideModals();
                  e.target.reset();
                  refreshAllData();
              }, 1500);
          } else {
              const errorMessage = result ? result.error : 'Failed to block user';
              setFeedbackMessage('block-feedback', `Error: ${errorMessage}`, true);
          }
      });

      // Helper function to block user - Expose globally for onclick handlers
      window.blockUser = (userId, userType, userName) => {
          document.getElementById('block-user-id').value = userId;
          document.getElementById('block-user-type').value = userType;
          document.getElementById('block-reason').value = '';
          showModal('block-user-modal');
      };

      // Helper function to unblock user - Expose globally for onclick handlers
      window.unblockUser = async (userId, userType, userName) => {
          showConfirmModal(
              'Unblock User',
              `Are you sure you want to unblock ${userName}?`,
              async () => {
                  const result = await postData('users/unblock', {
                      user_id: parseInt(userId),
                      user_type: userType
                  });
                  
                  if (result && !result.error) {
                      alert('User unblocked successfully!');
                      refreshAllData();
                  } else {
                      const errorMessage = result ? result.error : 'Failed to unblock user';
                      alert(`Error: ${errorMessage}`);
                  }
              }
          );
      };

      document.getElementById('settings-tabs').addEventListener('click', e => {
          if(e.target.classList.contains('settings-tab')) {
              document.querySelectorAll('.settings-tab').forEach(tab => tab.classList.remove('active'));
              document.querySelectorAll('.settings-content').forEach(content => content.classList.remove('active'));
              e.target.classList.add('active');
              document.getElementById(`${e.target.dataset.target}-content`).classList.add('active');
          }
      });

      // --- DATA REFRESH & INITIALIZATION ---
      const refreshUnreadCount = async () => { const data = await fetchData('unread-feedback-count'); updateBadges(null, data?.count); };
      // Debounce mechanism to prevent rapid calls
      let refreshTimeout = null;
      const refreshDashboardData = async () => {
          // Clear any pending refresh
          if (refreshTimeout) {
              clearTimeout(refreshTimeout);
          }
          
          // Debounce the refresh by 1 second (faster response)
          refreshTimeout = setTimeout(async () => {
              const [stats, pending, active, availableDrivers] = await Promise.all([ 
                  fetchData('dashboard-stats'), 
                  fetchData('pending-rides'), 
                  fetchData('active-rides'), 
                  fetchData('available-drivers') 
              ]);
              if (!stats) return; 
          updateDashboardStats(stats);
          
          const oldPendingIds = new Set(allPendingRides.map(r => r.id));
          allPendingRides = pending || [];
          allActiveRides = active || [];

          allPendingRides.forEach(ride => { if (!oldPendingIds.has(ride.id)) { recentNotifications.unshift(`New ride from ${ride.user_name} at ${ride.request_time}`); } });
          if (recentNotifications.length > 10) recentNotifications.length = 10;
          
          updateLiveMap();
          
          renderPendingRides(allPendingRides, availableDrivers || [], 'pending-rides-summary-list');
          renderPendingRides(allPendingRides, availableDrivers || [], 'pending-rides-container');
          updatePendingRidesStats(allPendingRides);
          updateActiveRidesTable(allActiveRides);
          updateBadges(stats);
          }, 1000); // 1 second debounce
      };
      const refreshAllData = async () => { 
          const [drivers, rides, passengers] = await Promise.all([ 
              fetchData('drivers'), 
              fetchData('all-rides-data'),
              fetchData('passengers')
          ]); 
          allDrivers = drivers || []; 
          allRidesHistory = rides || []; 
          allPassengers = passengers || [];
          updateDriversTable(); 
          updatePassengersTable();
          updateRideHistoryTable(); 
          refreshDashboardData(); 
          refreshUnreadCount(); 
      };
      const initDashboardMap = () => { if (!dashboardMap) { dashboardMap = L.map('dashboard-map').setView([13.88, 39.46], 10); L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(dashboardMap); } }
      
      document.querySelector('.analytics-filter-btn[data-period="week"]').classList.add('active-filter');
      showPane('dashboard');
      refreshAllData();
      setInterval(refreshDashboardData, 15000); // 15 seconds - good balance
      setInterval(refreshUnreadCount, 30000); // 30 seconds for notifications

      // Language persistence for admin dashboard - fixed to prevent infinite redirects
      const savedLang = localStorage.getItem('adminLanguage');
      const currentLang = '{{ session.get("language", "en") }}';
      
      // Only redirect if there's a saved preference different from current AND
      // we haven't just changed the language (check for redirect flag)
      const justChanged = sessionStorage.getItem('languageJustChanged');
      if (savedLang && savedLang !== currentLang && !justChanged) {
          // Set flag to prevent immediate redirect after language change
          sessionStorage.setItem('languageJustChanged', 'true');
          document.cookie = `language_preference=${savedLang}; max-age=${365*24*60*60}; path=/`;
          window.location.href = `/change_language/${savedLang}`;
      } else {
          // Clear the flag if it exists and save current language
          sessionStorage.removeItem('languageJustChanged');
          localStorage.setItem('adminLanguage', currentLang);
      }

      // Language dropdown functionality
      const langDropdownBtn = document.getElementById('lang-dropdown-btn');
      const langDropdownContent = document.getElementById('lang-dropdown-content');
      
      if (langDropdownBtn && langDropdownContent) {
          langDropdownBtn.addEventListener('click', (e) => {
              e.stopPropagation();
              langDropdownContent.classList.toggle('show');
          });

          // Close dropdown when clicking outside
          document.addEventListener('click', (e) => {
              if (!langDropdownBtn.contains(e.target) && !langDropdownContent.contains(e.target)) {
                  langDropdownContent.classList.remove('show');
              }
          });

          // Update language links to include persistence
          document.querySelectorAll('.lang-dropdown-content a').forEach(link => {
              link.addEventListener('click', (e) => {
                  const lang = e.target.href.split('/').pop();
                  localStorage.setItem('adminLanguage', lang);
                  document.cookie = `language_preference=${lang}; max-age=${365*24*60*60}; path=/`;
              });
          });
      }

      // --- DRIVER EARNINGS FUNCTIONALITY ---
      let allDriverEarnings = [];
      let currentEarningsFilters = {};

      // Initialize earnings data
      const initEarningsData = async () => {
          await loadDriverEarnings();
          await loadCommissionSettings();
          populateDriverFilter();
      };

      // Load driver earnings data
      const loadDriverEarnings = async () => {
          try {
              const params = new URLSearchParams(currentEarningsFilters);
              const response = await fetch(`${API_BASE_URL}/earnings/drivers?${params}`);
              const data = await response.json();
              
              if (data.success) {
                  allDriverEarnings = data.earnings;
                  updateEarningsTable();
                  updateEarningsSummary();
              }
          } catch (error) {
              console.error('Error loading driver earnings:', error);
          }
      };

      // Update earnings table
      const updateEarningsTable = () => {
          const tbody = document.getElementById('driver-earnings-table-body');
          tbody.innerHTML = '';

          if (!allDriverEarnings.length) {
              tbody.innerHTML = '<tr><td colspan="8" class="text-center p-8 text-secondary">No earnings data found</td></tr>';
              return;
          }

          allDriverEarnings.forEach(earning => {
              const row = tbody.insertRow();
              row.innerHTML = `
                  <td class="p-3">
                      <div class="flex items-center">
                          <img src="/${earning.profile_picture || 'static/img/default_user.svg'}" class="h-10 w-10 rounded-full mr-3 object-cover">
                          <div>
                              <p class="font-semibold text-primary">${earning.driver_name}</p>
                              <p class="text-sm text-secondary">${earning.phone_number}</p>
                          </div>
                      </div>
                  </td>
                  <td class="p-3">
                      <span class="px-2 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-medium">
                          ${earning.vehicle_type}
                      </span>
                  </td>
                  <td class="p-3 font-semibold">${earning.total_rides}</td>
                  <td class="p-3 font-semibold">${earning.total_fare.toFixed(2)} ETB</td>
                  <td class="p-3 text-red-600 font-semibold">${earning.total_commission.toFixed(2)} ETB</td>
                  <td class="p-3 text-green-600 font-semibold">${earning.total_earnings.toFixed(2)} ETB</td>
                  <td class="p-3">${earning.avg_earnings_per_ride.toFixed(2)} ETB</td>
                  <td class="p-3">
                      <div class="flex gap-2">
                          <button class="btn-modern btn-secondary text-xs px-3 py-1" onclick="viewDriverEarningsDetail(${earning.driver_id})">
                              View Details
                          </button>
                      </div>
                  </td>
              `;
          });
      };

      // Update earnings summary cards
      const updateEarningsSummary = () => {
          const totalEarnings = allDriverEarnings.reduce((sum, e) => sum + e.total_earnings, 0);
          const totalCommission = allDriverEarnings.reduce((sum, e) => sum + e.total_commission, 0);
          const activeDrivers = allDriverEarnings.length;
          const pendingPayments = allDriverEarnings.filter(e => e.payment_status === 'Pending').length;

          animateNumber(document.getElementById('total-driver-earnings'), totalEarnings, ' ETB');
          animateNumber(document.getElementById('total-commission'), totalCommission, ' ETB');
          animateNumber(document.getElementById('active-drivers-count'), activeDrivers);
          animateNumber(document.getElementById('pending-payments-count'), pendingPayments);
      };

      // Load commission settings
      const loadCommissionSettings = async () => {
          try {
              const response = await fetch(`${API_BASE_URL}/commission-settings`);
              const data = await response.json();
              
              if (data.success) {
                  // Store commission settings for later use
                  window.commissionSettings = data.commission_settings;
              }
          } catch (error) {
              console.error('Error loading commission settings:', error);
          }
      };

      // Populate driver filter dropdown
      const populateDriverFilter = async () => {
          try {
              const response = await fetch(`${API_BASE_URL}/drivers`);
              const data = await response.json();
              
              if (data.success) {
                  const select = document.getElementById('earnings-driver-filter');
                  select.innerHTML = '<option value="">All Drivers</option>';
                  
                  data.drivers.forEach(driver => {
                      const option = document.createElement('option');
                      option.value = driver.id;
                      option.textContent = driver.name;
                      select.appendChild(option);
                  });
              }
          } catch (error) {
              console.error('Error loading drivers for filter:', error);
          }
      };

      // Process unpaid rides (calculate earnings for completed rides that haven't been processed)
      const processUnpaidRides = async () => {
          try {
              setFeedbackMessage('earnings-feedback', 'Processing unpaid rides...', false);
              
              const response = await fetch(`${API_BASE_URL}/earnings/calculate`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({})
              });
              const data = await response.json();
              
              if (data.success) {
                  if (data.processed_count > 0) {
                      setFeedbackMessage('earnings-feedback', `✅ Processed ${data.processed_count} unpaid rides and calculated earnings`, false);
                  } else {
                      setFeedbackMessage('earnings-feedback', '✅ All rides are already processed - no unpaid rides found', false);
                  }
                  await loadDriverEarnings();
              } else {
                  setFeedbackMessage('earnings-feedback', `❌ Error: ${data.error}`, true);
              }
          } catch (error) {
              console.error('Error processing unpaid rides:', error);
              setFeedbackMessage('earnings-feedback', '❌ Error processing unpaid rides', true);
          }
      };

      // Apply earnings filters
      const applyEarningsFilters = () => {
          const startDate = document.getElementById('earnings-start-date').value;
          const endDate = document.getElementById('earnings-end-date').value;
          const driverId = document.getElementById('earnings-driver-filter').value;

          currentEarningsFilters = {};
          if (startDate) currentEarningsFilters.start_date = startDate;
          if (endDate) currentEarningsFilters.end_date = endDate;
          if (driverId) currentEarningsFilters.driver_id = driverId;

          loadDriverEarnings();
      };

      // View driver earnings detail
      window.viewDriverEarningsDetail = async (driverId) => {
          try {
              const params = new URLSearchParams(currentEarningsFilters);
              const response = await fetch(`${API_BASE_URL}/earnings/driver/${driverId}?${params}`);
              const data = await response.json();
              
              if (data.success) {
                  // Create and show modal with driver earnings detail
                  showDriverEarningsDetailModal(data);
              }
          } catch (error) {
              console.error('Error loading driver earnings detail:', error);
          }
      };

      // Show driver earnings detail modal
      const showDriverEarningsDetailModal = (data) => {
          const modal = document.createElement('div');
          modal.className = 'modal fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
          modal.innerHTML = `
              <div class="modal-content bg-white dark:bg-gray-800 rounded-lg p-6 max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
                  <div class="flex justify-between items-center mb-6">
                      <h3 class="text-xl font-semibold text-primary">${data.driver.name} - Earnings Detail</h3>
                      <button onclick="this.closest('.modal').remove()" class="text-gray-500 hover:text-gray-700">
                          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                          </svg>
                      </button>
                  </div>
                  
                  <!-- Summary -->
                  <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                      <div class="stat-card-modern">
                          <div class="stat-icon-modern gradient-bg-primary">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                              </svg>
                          </div>
                          <div>
                              <p class="text-xs text-secondary mb-1">Total Rides</p>
                              <p class="text-2xl font-bold text-primary">${data.summary.total_rides}</p>
                          </div>
                      </div>
                      <div class="stat-card-modern">
                          <div class="stat-icon-modern gradient-bg-success">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"></path>
                              </svg>
                          </div>
                          <div>
                              <p class="text-xs text-secondary mb-1">Total Earnings</p>
                              <p class="text-2xl font-bold text-primary">${data.summary.total_earnings.toFixed(2)} ETB</p>
                          </div>
                      </div>
                      <div class="stat-card-modern">
                          <div class="stat-icon-modern gradient-bg-secondary">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                              </svg>
                          </div>
                          <div>
                              <p class="text-xs text-secondary mb-1">Commission</p>
                              <p class="text-2xl font-bold text-primary">${data.summary.total_commission.toFixed(2)} ETB</p>
                          </div>
                      </div>
                      <div class="stat-card-modern">
                          <div class="stat-icon-modern gradient-bg-warning">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path>
                              </svg>
                          </div>
                          <div>
                              <p class="text-xs text-secondary mb-1">Avg per Ride</p>
                              <p class="text-2xl font-bold text-primary">${data.summary.avg_earnings_per_ride.toFixed(2)} ETB</p>
                          </div>
                      </div>
                  </div>

                  <!-- Earnings Table -->
                  <div class="modern-card p-4">
                      <h4 class="text-lg font-semibold text-primary mb-4">Individual Ride Earnings</h4>
                      <div class="overflow-x-auto">
                          <table class="w-full text-left">
                              <thead>
                                  <tr class="border-b border-border">
                                      <th class="p-2 font-semibold text-primary">Ride ID</th>
                                      <th class="p-2 font-semibold text-primary">Route</th>
                                      <th class="p-2 font-semibold text-primary">Gross Fare</th>
                                      <th class="p-2 font-semibold text-primary">Commission</th>
                                      <th class="p-2 font-semibold text-primary">Driver Earnings</th>
                                      <th class="p-2 font-semibold text-primary">Date</th>
                                      <th class="p-2 font-semibold text-primary">Status</th>
                                  </tr>
                              </thead>
                              <tbody>
                                  ${data.earnings.map(earning => `
                                      <tr class="border-b border-border">
                                          <td class="p-2">#${earning.ride_id}</td>
                                          <td class="p-2 text-sm">
                                              <div>${earning.ride?.pickup_address || 'N/A'}</div>
                                              <div class="text-secondary">→ ${earning.ride?.dest_address || 'N/A'}</div>
                                          </td>
                                          <td class="p-2 font-semibold">${earning.gross_fare.toFixed(2)} ETB</td>
                                          <td class="p-2 text-red-600">${earning.commission_amount.toFixed(2)} ETB</td>
                                          <td class="p-2 text-green-600 font-semibold">${earning.driver_earnings.toFixed(2)} ETB</td>
                                          <td class="p-2 text-sm">${new Date(earning.created_at).toLocaleDateString()}</td>
                                          <td class="p-2">
                                              <span class="px-2 py-1 rounded-full text-xs font-medium ${
                                                  earning.payment_status === 'Paid' ? 'bg-green-100 text-green-800' :
                                                  earning.payment_status === 'Pending' ? 'bg-yellow-100 text-yellow-800' :
                                                  'bg-red-100 text-red-800'
                                              }">
                                                  ${earning.payment_status}
                                              </span>
                                          </td>
                                      </tr>
                                  `).join('')}
                              </tbody>
                          </table>
                      </div>
                  </div>
              </div>
          `;
          document.body.appendChild(modal);
      };

      // Event listeners for earnings functionality
      document.getElementById('calculate-earnings-btn')?.addEventListener('click', processUnpaidRides);
      document.getElementById('earnings-filter-btn')?.addEventListener('click', applyEarningsFilters);
      document.getElementById('commission-settings-btn')?.addEventListener('click', async () => {
          try {
              const response = await fetch(`${API_BASE_URL}/commission-settings`);
              const data = await response.json();
              
              if (data.success) {
                  // Populate the form with current settings
                  document.getElementById('bajaj-commission-rate').value = data.settings.bajaj_rate;
                  document.getElementById('car-commission-rate').value = data.settings.car_rate;
                  showModal('commission-settings-modal');
              } else {
                  setFeedbackMessage('commission-feedback', 'Error loading commission settings', 'error');
              }
          } catch (error) {
              console.error('Error loading commission settings:', error);
              setFeedbackMessage('commission-feedback', 'Error loading commission settings', 'error');
          }
      });

      // Initialize earnings when driver-earnings pane is shown
      document.addEventListener('click', (e) => {
          if (e.target.closest('[data-pane="driver-earnings"]')) {
              // Auto-load earnings data when pane is opened
              initEarningsData();
              // Show helpful message
              setFeedbackMessage('earnings-feedback', '📊 Loading driver earnings data...', false);
          }
      });

      // --- ENHANCED PENDING RIDES FUNCTIONALITY ---
      let driverSuggestions = {};

      // Enhanced pending rides display with driver suggestions
      const updatePendingRidesEnhanced = (rides) => {
          const container = document.getElementById('pending-rides-container');
          container.innerHTML = '';

          if (!rides || rides.length === 0) {
              container.innerHTML = `
                  <div class="modern-card p-8 text-center">
                      <svg class="w-16 h-16 mx-auto text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path>
                      </svg>
                      <h3 class="text-lg font-semibold text-primary mb-2">No Pending Requests</h3>
                      <p class="text-secondary">All ride requests have been assigned to drivers</p>
                  </div>
              `;
              return;
          }

          rides.forEach((ride, index) => {
              const rideCard = createEnhancedRideCard(ride, index);
              container.appendChild(rideCard);
          });

          // Update stats
          updatePendingRidesStats(rides);
      };

      // Create enhanced ride card with driver suggestions
      const createEnhancedRideCard = (ride, index) => {
          const card = document.createElement('div');
          card.className = 'ride-card animate-fade-in';
          card.style.animationDelay = `${index * 0.1}s`;
          
          const timeAgo = getTimeAgo(ride.request_time);
          const vehicleIcon = ride.vehicle_type === 'Car' ? '🚗' : '🏍️';
          
          card.innerHTML = `
              <div class="flex justify-between items-start mb-4">
                  <div class="flex items-center">
                      <div class="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white text-xl mr-4">
                          ${vehicleIcon}
                      </div>
                      <div>
                          <h4 class="font-semibold text-primary">New Ride Request</h4>
                          <p class="text-sm text-secondary">${ride.passenger_name} • ${timeAgo}</p>
                      </div>
                  </div>
                  <div class="text-right">
                      <p class="text-lg font-bold text-primary">${ride.fare} ETB</p>
                      <p class="text-sm text-secondary">${ride.vehicle_type}</p>
                  </div>
              </div>

              <div class="mb-4">
                  <div class="flex items-center mb-2">
                      <svg class="w-4 h-4 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                      </svg>
                      <span class="text-sm font-medium text-primary">From:</span>
                      <span class="text-sm text-secondary ml-2">${ride.pickup_address}</span>
                  </div>
                  <div class="flex items-center">
                      <svg class="w-4 h-4 text-red-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                      </svg>
                      <span class="text-sm font-medium text-primary">To:</span>
                      <span class="text-sm text-secondary ml-2">${ride.dest_address}</span>
                  </div>
              </div>

              <!-- Driver Suggestions Section -->
              <div class="border-t border-border pt-4">
                  <div class="flex justify-between items-center mb-3">
                      <h5 class="font-semibold text-primary">Suggested Drivers</h5>
                      <button class="btn-modern btn-secondary text-xs px-3 py-1" onclick="loadDriverSuggestions(${ride.id})">
                          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
                          </svg>
                          Refresh
                      </button>
                  </div>
                  <div id="suggestions-${ride.id}" class="space-y-2">
                      <div class="text-center py-4">
                          <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-500 mx-auto"></div>
                          <p class="text-sm text-secondary mt-2">Loading suggestions...</p>
                      </div>
                  </div>
              </div>
          `;

          // Load driver suggestions for this ride
          loadDriverSuggestions(ride.id);
          
          return card;
      };

      // Load driver suggestions for a specific ride
      window.loadDriverSuggestions = async (rideId) => {
          try {
              const ride = allPendingRides.find(r => r.id === rideId);
              if (!ride) return;

              const suggestionsContainer = document.getElementById(`suggestions-${rideId}`);
              
              const response = await fetch(`${API_BASE_URL}/suggest-drivers`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                      ride_id: rideId,
                      pickup_lat: ride.pickup_lat || 9.0192, // Default Addis Ababa coordinates
                      pickup_lon: ride.pickup_lon || 38.7525,
                      vehicle_type: ride.vehicle_type
                  })
              });

              const data = await response.json();
              
              if (data.success && data.suggestions.length > 0) {
                  driverSuggestions[rideId] = data.suggestions;
                  suggestionsContainer.innerHTML = data.suggestions.map((driver, index) => `
                      <div class="driver-card ${index === 0 ? 'selected' : ''}" onclick="selectDriver(${rideId}, ${driver.driver_id})">
                          <div class="flex items-center justify-between">
                              <div class="flex items-center">
                                  <img src="/${driver.profile_picture || 'static/img/default_user.svg'}" class="h-10 w-10 rounded-full mr-3 object-cover">
                                  <div>
                                      <p class="font-semibold text-primary">${driver.name}</p>
                                      <div class="flex items-center">
                                          <span class="text-yellow-500 text-sm">★ ${driver.rating}</span>
                                          <span class="status-dot ${driver.status === 'Available' ? 'online' : 'offline'} ml-2"></span>
                                          <span class="text-xs text-secondary ml-2">${driver.estimated_distance}</span>
                                      </div>
                                  </div>
                              </div>
                              <div class="text-right">
                                  <div class="flex items-center mb-1">
                                      <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">${driver.score}% match</span>
                                  </div>
                                  <p class="text-xs text-secondary">${driver.total_rides} rides</p>
                              </div>
                          </div>
                          <div class="mt-3 flex gap-2">
                              <button class="btn-modern btn-success text-xs px-3 py-1 flex-1" onclick="assignDriver(${rideId}, ${driver.driver_id})">
                                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                                  </svg>
                                  Assign
                              </button>
                              <button class="btn-modern btn-secondary text-xs px-3 py-1" onclick="callDriver('${driver.phone_number}')">
                                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path>
                                  </svg>
                                  Call
                              </button>
                          </div>
                      </div>
                  `).join('');
              } else {
                  suggestionsContainer.innerHTML = `
                      <div class="text-center py-4">
                          <svg class="w-8 h-8 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"></path>
                          </svg>
                          <p class="text-sm text-secondary">No available drivers found</p>
                      </div>
                  `;
              }
          } catch (error) {
              console.error('Error loading driver suggestions:', error);
              const suggestionsContainer = document.getElementById(`suggestions-${rideId}`);
              suggestionsContainer.innerHTML = `
                  <div class="text-center py-4">
                      <p class="text-sm text-red-500">Error loading suggestions</p>
                  </div>
              `;
          }
      };

      // Select a driver (visual feedback)
      window.selectDriver = (rideId, driverId) => {
          const suggestionsContainer = document.getElementById(`suggestions-${rideId}`);
          const cards = suggestionsContainer.querySelectorAll('.driver-card');
          cards.forEach(card => card.classList.remove('selected'));
          event.target.closest('.driver-card').classList.add('selected');
      };

      // Assign driver to ride
      window.assignDriver = async (rideId, driverId) => {
          try {
              const response = await fetch(`${API_BASE_URL}/assign-ride`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                      ride_id: rideId,
                      driver_id: driverId
                  })
              });

              const data = await response.json();
              
              if (data.success) {
                  setFeedbackMessage('assignment-feedback', 'Driver assigned successfully!');
                  await refreshAllData();
              } else {
                  setFeedbackMessage('assignment-feedback', data.error, 'error');
              }
          } catch (error) {
              console.error('Error assigning driver:', error);
              setFeedbackMessage('assignment-feedback', 'Error assigning driver', 'error');
          }
      };

      // Call driver
      window.callDriver = (phoneNumber) => {
          window.open(`tel:${phoneNumber}`, '_self');
      };

      // Update pending rides stats
      const updatePendingRidesStats = (rides) => {
          const availableDrivers = allDrivers.filter(d => d.status === 'Available').length;
          
          // Calculate average wait time
          let avgWaitTime = 0;
          if (rides.length > 0) {
              const totalWaitTime = rides.reduce((sum, ride) => {
                  try {
                      const requestTime = new Date(ride.request_time);
                      const now = new Date();
                      const waitTime = (now - requestTime) / (1000 * 60); // minutes
                      return sum + Math.max(0, waitTime); // Ensure non-negative
                  } catch (error) {
                      console.warn('Error parsing request_time:', ride.request_time, error);
                      return sum;
                  }
              }, 0);
              avgWaitTime = Math.round(totalWaitTime / rides.length);
          }
          
          // Calculate success rate based on completed vs total rides from ride history
          const totalRides = allRidesHistory.length;
          const completedRides = allRidesHistory.filter(ride => ride.status === 'Completed').length;
          const successRate = totalRides > 0 ? Math.round((completedRides / totalRides) * 100) : 0;
          
          // Update the UI elements
          const pendingCountEl = document.getElementById('pending-count');
          const availableDriversEl = document.getElementById('available-drivers-count');
          const avgWaitTimeEl = document.getElementById('avg-wait-time');
          const successRateEl = document.getElementById('assignment-success-rate');
          
          if (pendingCountEl) animateNumber(pendingCountEl, rides.length);
          if (availableDriversEl) animateNumber(availableDriversEl, availableDrivers);
          if (avgWaitTimeEl) animateNumber(avgWaitTimeEl, avgWaitTime, ' min');
          if (successRateEl) animateNumber(successRateEl, successRate, '%');
      };


      // Event listeners for enhanced pending rides
      document.getElementById('refresh-pending-btn')?.addEventListener('click', refreshAllData);

      // Override the existing updatePendingRides function
      const originalUpdatePendingRides = window.updatePendingRides;
      window.updatePendingRides = (rides) => {
          allPendingRides = rides;
          updatePendingRidesEnhanced(rides);
      };

      // --- BATCH OPERATIONS AND QUICK ACTIONS ---
      let selectedDrivers = new Set();

      // Enhanced driver table with batch operations
      const updateDriversTableEnhanced = (drivers) => {
          const tbody = document.getElementById('drivers-table-body');
          tbody.innerHTML = '';

          if (!drivers || drivers.length === 0) {
              tbody.innerHTML = '<tr><td colspan="8" class="text-center p-8 text-secondary">No drivers found</td></tr>';
              return;
          }

          drivers.forEach(driver => {
              const row = tbody.insertRow();
              row.innerHTML = `
                  <td class="p-3">
                      <input type="checkbox" class="driver-checkbox rounded border-border" data-driver-id="${driver.id}">
                  </td>
                  <td class="p-3">
                      <div class="flex items-center">
                          <img src="/${driver.profile_picture || 'static/img/default_user.svg'}" class="h-10 w-10 rounded-full mr-3 object-cover">
                          <div>
                              <p class="font-semibold text-primary">${driver.name}</p>
                              <p class="text-sm text-secondary">ID: ${driver.id}</p>
                          </div>
                      </div>
                  </td>
                  <td class="p-3">
                      <div>
                          <p class="text-sm font-medium text-primary">${driver.phone_number}</p>
                          <p class="text-xs text-secondary">${driver.email || 'No email'}</p>
                      </div>
                  </td>
                  <td class="p-3">
                      <div>
                          <span class="px-2 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-medium">${driver.vehicle_type}</span>
                          <p class="text-xs text-secondary mt-1">${driver.vehicle_details}</p>
                      </div>
                  </td>
                  <td class="p-3">
                      <div class="flex items-center">
                          <span class="status-dot ${driver.status === 'Available' ? 'online' : driver.status === 'On Trip' ? 'busy' : 'offline'}"></span>
                          <span class="text-xs font-medium">${driver.status}</span>
                      </div>
                  </td>
                  <td class="p-3">
                      <div class="flex items-center">
                          <span class="text-yellow-500 text-sm">★ ${driver.rating || 'N/A'}</span>
                      </div>
                  </td>
                  <td class="p-3">
                      <p class="text-sm font-semibold text-green-600">${driver.total_earnings || 0} ETB</p>
                  </td>
                  <td class="p-3">
                      <div class="flex gap-2">
                          <button class="btn-modern btn-secondary text-xs px-2 py-1" onclick="callDriver('${driver.phone_number}')" title="Call Driver">
                              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"></path>
                              </svg>
                          </button>
                          <button class="btn-modern btn-success text-xs px-2 py-1" onclick="toggleDriverStatus(${driver.id}, '${driver.status}')" title="Toggle Status">
                              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"></path>
                              </svg>
                          </button>
                          <button class="btn-modern btn-danger text-xs px-2 py-1" onclick="blockDriver(${driver.id})" title="Block Driver">
                              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728L5.636 5.636m12.728 12.728L18.364 5.636M5.636 18.364l12.728-12.728"></path>
                              </svg>
                          </button>
                      </div>
                  </td>
              `;
          });

          // Add event listeners for checkboxes
          addDriverCheckboxListeners();
      };

      // Add checkbox event listeners
      const addDriverCheckboxListeners = () => {
          const checkboxes = document.querySelectorAll('.driver-checkbox');
          const selectAllCheckbox = document.getElementById('select-all-drivers');
          const batchActions = document.getElementById('batch-driver-actions');

          checkboxes.forEach(checkbox => {
              checkbox.addEventListener('change', (e) => {
                  const driverId = parseInt(e.target.dataset.driverId);
                  if (e.target.checked) {
                      selectedDrivers.add(driverId);
                  } else {
                      selectedDrivers.delete(driverId);
                  }
                  updateBatchActionsVisibility();
              });
          });

          selectAllCheckbox?.addEventListener('change', (e) => {
              checkboxes.forEach(checkbox => {
                  checkbox.checked = e.target.checked;
                  const driverId = parseInt(checkbox.dataset.driverId);
                  if (e.target.checked) {
                      selectedDrivers.add(driverId);
                  } else {
                      selectedDrivers.delete(driverId);
                  }
              });
              updateBatchActionsVisibility();
          });
      };

      // Update batch actions visibility
      const updateBatchActionsVisibility = () => {
          const batchActions = document.getElementById('batch-driver-actions');
          if (selectedDrivers.size > 0) {
              batchActions.style.display = 'flex';
          } else {
              batchActions.style.display = 'none';
          }
      };

      // Batch operations
      const batchUpdateDriverStatus = async (status) => {
          if (selectedDrivers.size === 0) return;

          try {
              const promises = Array.from(selectedDrivers).map(driverId => 
                  fetch(`${API_BASE_URL}/drivers/${driverId}/status`, {
                      method: 'PUT',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ status })
                  })
              );

              await Promise.all(promises);
              setFeedbackMessage('batch-feedback', `Updated ${selectedDrivers.size} drivers to ${status}`);
              selectedDrivers.clear();
              document.getElementById('select-all-drivers').checked = false;
              updateBatchActionsVisibility();
              await refreshAllData();
          } catch (error) {
              console.error('Error in batch update:', error);
              setFeedbackMessage('batch-feedback', 'Error updating drivers', 'error');
          }
      };

      const batchBlockDrivers = async () => {
          if (selectedDrivers.size === 0) return;

          if (!confirm(`Are you sure you want to block ${selectedDrivers.size} drivers?`)) return;

          try {
              const promises = Array.from(selectedDrivers).map(driverId => 
                  fetch(`${API_BASE_URL}/users/block`, {
                      method: 'POST',
                      headers: { 'Content-Type': 'application/json' },
                      body: JSON.stringify({ 
                          user_id: driverId, 
                          user_type: 'driver',
                          reason: 'Batch block operation'
                      })
                  })
              );

              await Promise.all(promises);
              setFeedbackMessage('batch-feedback', `Blocked ${selectedDrivers.size} drivers`);
              selectedDrivers.clear();
              document.getElementById('select-all-drivers').checked = false;
              updateBatchActionsVisibility();
              await refreshAllData();
          } catch (error) {
              console.error('Error in batch block:', error);
              setFeedbackMessage('batch-feedback', 'Error blocking drivers', 'error');
          }
      };

      // Quick actions
      window.toggleDriverStatus = async (driverId, currentStatus) => {
          const newStatus = currentStatus === 'Available' ? 'Offline' : 'Available';
          try {
              const response = await fetch(`${API_BASE_URL}/drivers/${driverId}/status`, {
                  method: 'PUT',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ status: newStatus })
              });

              if (response.ok) {
                  setFeedbackMessage('driver-feedback', `Driver status updated to ${newStatus}`);
                  await refreshAllData();
              }
          } catch (error) {
              console.error('Error updating driver status:', error);
              setFeedbackMessage('driver-feedback', 'Error updating status', 'error');
          }
      };

      window.blockDriver = async (driverId) => {
          if (!confirm('Are you sure you want to block this driver?')) return;

          try {
              const response = await fetch(`${API_BASE_URL}/users/block`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ 
                      user_id: driverId, 
                      user_type: 'driver',
                      reason: 'Manual block by admin'
                  })
              });

              if (response.ok) {
                  setFeedbackMessage('driver-feedback', 'Driver blocked successfully');
                  await refreshAllData();
              }
          } catch (error) {
              console.error('Error blocking driver:', error);
              setFeedbackMessage('driver-feedback', 'Error blocking driver', 'error');
          }
      };

      // Event listeners for batch operations
      document.getElementById('batch-online-drivers')?.addEventListener('click', () => batchUpdateDriverStatus('Available'));
      document.getElementById('batch-offline-drivers')?.addEventListener('click', () => batchUpdateDriverStatus('Offline'));
      document.getElementById('batch-block-drivers')?.addEventListener('click', batchBlockDrivers);
      document.getElementById('clear-driver-filters-btn')?.addEventListener('click', () => {
          document.getElementById('driver-search-input').value = '';
          document.getElementById('driver-status-filter').value = 'All';
          document.getElementById('driver-vehicle-filter').value = 'All';
          // Trigger filter update
          refreshAllData();
      });

      // Export drivers functionality
      document.getElementById('export-drivers-btn')?.addEventListener('click', async () => {
          try {
              console.log('Starting driver export...');
              const response = await fetch(`${API_BASE_URL}/drivers/export`);
              console.log('Export response status:', response.status);
              
              if (response.ok) {
                  const blob = await response.blob();
                  const url = window.URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = `drivers_export_${new Date().toISOString().split('T')[0]}.csv`;
                  document.body.appendChild(a);
                  a.click();
                  window.URL.revokeObjectURL(url);
                  document.body.removeChild(a);
                  setFeedbackMessage('export-feedback', 'Drivers exported successfully!');
                  console.log('Driver export completed successfully');
              } else {
                  const errorText = await response.text();
                  console.error('Export failed:', response.status, errorText);
                  setFeedbackMessage('export-feedback', `Error exporting drivers: ${response.status}`, 'error');
              }
          } catch (error) {
              console.error('Export error:', error);
              setFeedbackMessage('export-feedback', `Error exporting drivers: ${error.message}`, 'error');
          }
      });

      // Export driver earnings functionality
      document.getElementById('export-earnings-btn')?.addEventListener('click', async () => {
          try {
              const response = await fetch(`${API_BASE_URL}/earnings/export`);
              if (response.ok) {
                  const blob = await response.blob();
                  const url = window.URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = `driver_earnings_export_${new Date().toISOString().split('T')[0]}.csv`;
                  document.body.appendChild(a);
                  a.click();
                  window.URL.revokeObjectURL(url);
                  document.body.removeChild(a);
                  setFeedbackMessage('export-feedback', 'Driver earnings exported successfully!');
              } else {
                  setFeedbackMessage('export-feedback', 'Error exporting driver earnings', 'error');
              }
          } catch (error) {
              console.error('Export earnings error:', error);
              setFeedbackMessage('export-feedback', 'Error exporting driver earnings', 'error');
          }
      });

      // Override the existing updateDriversTable function
      const originalUpdateDriversTable = window.updateDriversTable;
      window.updateDriversTable = (drivers) => {
          allDrivers = drivers;
          updateDriversTableEnhanced(drivers);
      };

      // Test function to add notifications (for debugging)
      window.addTestNotification = (message) => {
          recentNotifications.unshift(message || 'Test notification - ' + new Date().toLocaleTimeString());
          const badge = document.getElementById('notification-badge');
          badge.textContent = recentNotifications.length;
          badge.classList.remove('hidden');
          console.log('Added test notification:', message);
      };

      // Add some initial test notifications
      setTimeout(() => {
          if (recentNotifications.length === 0) {
              addTestNotification('Welcome to the dispatcher dashboard!');
              addTestNotification('System is running smoothly');
          }
      }, 2000);

      // --- QUICK ACCESS FUNCTIONS ---
      window.exportDrivers = async () => {
          try {
              const response = await fetch(`${API_BASE_URL}/drivers/export`);
              if (response.ok) {
                  const blob = await response.blob();
                  const url = window.URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = `drivers_export_${new Date().toISOString().split('T')[0]}.csv`;
                  document.body.appendChild(a);
                  a.click();
                  window.URL.revokeObjectURL(url);
                  document.body.removeChild(a);
                  setFeedbackMessage('export-feedback', 'Drivers data exported successfully!');
              } else {
                  setFeedbackMessage('export-feedback', 'Error exporting data', 'error');
              }
          } catch (error) {
              console.error('Export error:', error);
              setFeedbackMessage('export-feedback', 'Error exporting data', 'error');
          }
      };

      // --- SIMPLE ANALYTICS FUNCTIONALITY ---
      // (updateAnalytics function already exists around line 310)

      const updateCharts = (charts) => {
          // Revenue Chart
          if (charts.revenue_over_time) {
              const ctx = document.getElementById('revenue-over-time-chart');
              if (ctx) {
                  if (revenueChart) revenueChart.destroy();
                  
                  revenueChart = new Chart(ctx, {
                      type: 'bar',
                      data: {
                          labels: charts.revenue_over_time.labels || [],
                          datasets: [{
                              label: 'Daily Revenue (ETB)',
                              data: charts.revenue_over_time.data || [],
                              backgroundColor: '#8B5CF6'
                          }]
                      },
                      options: {
                          responsive: true,
                          maintainAspectRatio: false,
                          plugins: {
                              legend: {
                                  display: false
                              }
                          },
                          scales: {
                              y: {
                                  beginAtZero: true
                              }
                          }
                      }
                  });
              }
          }
          
          // Vehicle Distribution Chart
          if (charts.vehicle_distribution) {
              const ctx = document.getElementById('vehicle-dist-chart');
              if (ctx) {
                  if (vehicleDistChart) vehicleDistChart.destroy();
                  
                  const labels = Object.keys(charts.vehicle_distribution);
                  const values = Object.values(charts.vehicle_distribution);
                  
                  vehicleDistChart = new Chart(ctx, {
                      type: 'doughnut',
                      data: {
                          labels: labels,
                          datasets: [{
                              data: values,
                              backgroundColor: ['#F59E0B', '#3B82F6', '#EF4444']
                          }]
                      },
                      options: {
                          responsive: true,
                          maintainAspectRatio: false,
                          plugins: {
                              legend: {
                                  position: 'bottom'
                              }
                          }
                      }
                  });
              }
          }
          
          // Payment Distribution Chart
          if (charts.payment_method_distribution) {
              const ctx = document.getElementById('payment-dist-chart');
              if (ctx) {
                  if (paymentDistChart) paymentDistChart.destroy();
                  
                  const labels = Object.keys(charts.payment_method_distribution);
                  const values = Object.values(charts.payment_method_distribution);
                  
                  paymentDistChart = new Chart(ctx, {
                      type: 'doughnut',
                      data: {
                          labels: labels,
                          datasets: [{
                              data: values,
                              backgroundColor: ['#10B981', '#8B5CF6', '#EF4444']
                          }]
                      },
                      options: {
                          responsive: true,
                          maintainAspectRatio: false,
                          plugins: {
                              legend: {
                                  position: 'bottom'
                              }
                          }
                      }
                  });
              }
          }
      };

      const updateTopDrivers = (drivers) => {
          const container = document.getElementById('top-drivers-list');
          if (!container) return;
          
          if (!drivers || drivers.length === 0) {
              container.innerHTML = '<p class="text-center text-gray-500">No driver data available</p>';
              return;
          }
          
          container.innerHTML = drivers.map(driver => `
              <div class="flex items-center justify-between p-2">
                  <div class="flex items-center">
                      <img src="/${driver.avatar}" class="h-10 w-10 rounded-full mr-4 object-cover" alt="${driver.name}">
                      <div>
                          <p class="font-semibold">${driver.name}</p>
                          <p class="text-xs text-gray-500">${driver.avg_rating} ⭐</p>
                      </div>
                  </div>
                  <p class="font-bold text-lg">${driver.completed_rides} rides</p>
              </div>
          `).join('');
      };

      // Setup filter buttons (using existing function from line 186)

      // Initialize analytics
      setupFilterButtons('analytics-period-btns', params => {
          currentAnalyticsParams = params;
          updateAnalytics();
      });

      // Set default active button
      document.addEventListener('DOMContentLoaded', () => {
          const weekBtn = document.querySelector('.analytics-filter-btn[data-period="week"]');
          if (weekBtn) {
              weekBtn.classList.add('bg-indigo-600', 'text-white');
          }
      });

      // Load analytics when analytics pane is shown
      document.addEventListener('click', (e) => {
          if (e.target.closest('[data-pane="analytics"]')) {
              setTimeout(() => {
                  updateAnalytics();
              }, 100);
          }
      });

      window.showCommissionSettings = async () => {
          try {
              const response = await fetch(`${API_BASE_URL}/commission-settings`);
              const data = await response.json();
              
              if (data.success) {
                  // Create commission settings modal
                  const modal = document.createElement('div');
                  modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
                  modal.innerHTML = `
                      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 w-full max-w-md">
                          <h3 class="text-lg font-semibold mb-4">Commission Settings</h3>
                          <form id="commission-form">
                              <div class="space-y-4">
                                  <div>
                                      <label class="block text-sm font-medium mb-2">Bajaj Commission Rate (%)</label>
                                      <input type="number" name="Bajaj" value="${data.settings.Bajaj.rate}" 
                                             class="w-full border rounded-md px-3 py-2" min="0" max="100" step="0.1">
                                  </div>
                                  <div>
                                      <label class="block text-sm font-medium mb-2">Car Commission Rate (%)</label>
                                      <input type="number" name="Car" value="${data.settings.Car.rate}" 
                                             class="w-full border rounded-md px-3 py-2" min="0" max="100" step="0.1">
                                  </div>
                              </div>
                              <div class="flex gap-3 mt-6">
                                  <button type="submit" class="flex-1 bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700">
                                      Save Settings
                                  </button>
                                  <button type="button" onclick="this.closest('.fixed').remove()" 
                                          class="flex-1 bg-gray-300 text-gray-700 py-2 px-4 rounded-md hover:bg-gray-400">
                                      Cancel
                                  </button>
                              </div>
                          </form>
                      </div>
                  `;
                  
                  document.body.appendChild(modal);
                  
                  // Handle form submission
                  modal.querySelector('#commission-form').addEventListener('submit', async (e) => {
                      e.preventDefault();
                      const formData = new FormData(e.target);
                      const settings = {};
                      
                      for (let [key, value] of formData.entries()) {
                          settings[key] = { rate: parseFloat(value) };
                      }
                      
                      try {
                          const response = await fetch(`${API_BASE_URL}/commission-settings`, {
                              method: 'POST',
                              headers: { 'Content-Type': 'application/json' },
                              body: JSON.stringify(settings)
                          });
                          
                          const result = await response.json();
                          if (result.success) {
                              setFeedbackMessage('commission-feedback', 'Commission settings updated successfully!');
                              modal.remove();
                          } else {
                              setFeedbackMessage('commission-feedback', result.error || 'Error updating settings', 'error');
                          }
                      } catch (error) {
                          setFeedbackMessage('commission-feedback', 'Error updating settings', 'error');
                      }
                  });
              }
          } catch (error) {
              console.error('Error loading commission settings:', error);
              setFeedbackMessage('commission-feedback', 'Error loading settings', 'error');
          }
      };
      
      // Initialize audio on first user interaction
      const initAudioOnInteraction = () => {
          initAudio();
          // Remove listeners after first interaction
          document.removeEventListener('click', initAudioOnInteraction);
          document.removeEventListener('keydown', initAudioOnInteraction);
          document.removeEventListener('touchstart', initAudioOnInteraction);
      };
      
      document.addEventListener('click', initAudioOnInteraction);
      document.addEventListener('keydown', initAudioOnInteraction);
      document.addEventListener('touchstart', initAudioOnInteraction);
  });