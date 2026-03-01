import React from 'react';

export default function AdminPageHeader({
  currentTab,
  adminMenuOpen,
  setAdminMenuOpen,
  groupedTabs,
  tab,
  setTab
}) {
  return (
    <div className="panel admin-page-header">
      <div className="panel-body">
        <div className="admin-page-top">
          <button
            type="button"
            className={`admin-hamburger ${adminMenuOpen ? 'open' : ''}`}
            aria-label="Admin menüsünü aç"
            aria-expanded={adminMenuOpen}
            onClick={() => setAdminMenuOpen((v) => !v)}
          >
            <span />
            <span />
            <span />
          </button>
          <div>
            <h3>{currentTab.label}</h3>
            <div className="muted">{currentTab.hint}</div>
          </div>
        </div>
        <div className={`admin-hamburger-menu ${adminMenuOpen ? 'open' : ''}`}>
          {Object.entries(groupedTabs).map(([section, sectionTabs]) => (
            <div key={`menu-${section}`} className="admin-nav-group">
              <div className="admin-nav-title">{section}</div>
              {sectionTabs.map((menuTab) => (
                <button
                  key={menuTab.key}
                  className={`admin-nav-item ${tab === menuTab.key ? 'active' : ''}`}
                  onClick={() => setTab(menuTab.key)}
                >
                  <div className="name">{menuTab.label}</div>
                  <div className="meta">{menuTab.hint}</div>
                </button>
              ))}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

