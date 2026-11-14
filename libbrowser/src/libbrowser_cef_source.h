/* Copyright (C) 2026 OXT-Beyond contributors.

 This file is part of OXT-Beyond.

 OXT-Beyond is free software; you can redistribute it and/or modify it under
 the terms of the GNU General Public License v3 as published by the Free
 Software Foundation.

 OXT-Beyond is distributed in the hope that it will be useful, but WITHOUT ANY
 WARRANTY; without even the implied warranty of MERCHANTABILITY or
 FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 for more details.

 You should have received a copy of the GNU General Public License
 along with OXT-Beyond.  If not see <http://www.gnu.org/licenses/>.  */

// htmlText without CefFrame::LoadString
//
// Up to CEF 74 the browser widget (libbrowser) and revBrowser set their
// htmlText with CefFrame::LoadString(html, url): the page is the html, and
// the document's URL is url (http://libbrowser_dummy_url/ or
// http://revbrowser_dummy_url/). So the page's relative links resolve
// against that URL, its origin is that URL's (localStorage and cookies
// work), and revBrowser's url property reports it. CEF removed LoadString
// (CEF 116); the replacement CEF suggests, a data: URL, would change all
// of these (tools/ci/browser-compat-check.livecodescript records them).
//
// So the page is loaded from its URL, and the request for that URL is
// answered with the html instead of going to the network:
//
//   MCCefPendingSource::Set(url, html)    before CefFrame::LoadURL(url)
//   MCCefPendingSource::Take(request url) in GetResourceHandler, for a
//                                         request of the main frame; a
//                                         resource handler with the html
//
// An html is answered once, for the next request of its URL, as LoadString
// loaded it once: going back to the page or reloading it asks the network
// for that URL, as it did with CEF 74. The URLs are compared as Chromium
// requests them (canonical, without a fragment).
//
// Set runs on the browser's UI thread, Take on CEF's IO thread: a mutex
// guards the map.

#ifndef __LIBBROWSER_CEF_SOURCE_H__
#define __LIBBROWSER_CEF_SOURCE_H__

#include <include/cef_parser.h>
#include <include/cef_resource_handler.h>
#include <include/cef_response.h>

#include <cstring>
#include <map>
#include <mutex>
#include <string>

// The URL as Chromium requests it: canonical (CefCreateURL goes through
// GURL), without its fragment, which a request never has
inline std::string MCCefSourceKey(const CefString &p_url)
{
	CefURLParts t_parts;
	if (!CefParseURL(p_url, t_parts))
	{
		std::string t_url = p_url.ToString();
		std::string::size_type t_hash = t_url.find('#');
		return t_hash == std::string::npos ? t_url : t_url.substr(0, t_hash);
	}
	cef_string_clear(&t_parts.fragment);
	CefString t_canonical;
	if (!CefCreateURL(t_parts, t_canonical))
		return p_url.ToString();
	return t_canonical.ToString();
}

class MCCefPendingSource
{
public:
	void Set(const CefString &p_url, const std::string &p_html)
	{
		std::lock_guard<std::mutex> t_lock(m_mutex);
		m_sources[MCCefSourceKey(p_url)] = p_html;
	}

	// Whether the page of p_url waits for its request (OnBeforeBrowse
	// comes before it)
	bool Has(const CefString &p_url)
	{
		std::lock_guard<std::mutex> t_lock(m_mutex);
		return m_sources.find(MCCefSourceKey(p_url)) != m_sources.end();
	}

	bool Take(const CefString &p_url, std::string &r_html)
	{
		std::lock_guard<std::mutex> t_lock(m_mutex);
		std::map<std::string, std::string>::iterator t_iter = m_sources.find(MCCefSourceKey(p_url));
		if (t_iter == m_sources.end())
			return false;
		r_html.swap(t_iter->second);
		m_sources.erase(t_iter);
		return true;
	}

private:
	std::mutex m_mutex;
	std::map<std::string, std::string> m_sources;
};

// The html as a text/html response in UTF-8, as LoadString gave it to
// Blink. Opened, read and cancelled on CEF's IO thread and its workers,
// one call at a time.
class MCCefSourceResourceHandler : public CefResourceHandler
{
public:
	explicit MCCefSourceResourceHandler(const std::string &p_html)
		: m_html(p_html), m_offset(0)
	{
	}

	bool Open(CefRefPtr<CefRequest> p_request, bool &r_handle_request, CefRefPtr<CefCallback> p_callback) override
	{
		r_handle_request = true;
		return true;
	}

	void GetResponseHeaders(CefRefPtr<CefResponse> p_response, int64_t &r_response_length, CefString &r_redirect_url) override
	{
		p_response->SetStatus(200);
		p_response->SetStatusText("OK");
		p_response->SetMimeType("text/html");
		p_response->SetCharset("utf-8");
		r_response_length = static_cast<int64_t>(m_html.size());
	}

	bool Read(void *p_data_out, int p_bytes_to_read, int &r_bytes_read, CefRefPtr<CefResourceReadCallback> p_callback) override
	{
		r_bytes_read = 0;
		if (m_offset >= m_html.size())
			return false;
		size_t t_count = m_html.size() - m_offset;
		if (t_count > static_cast<size_t>(p_bytes_to_read))
			t_count = static_cast<size_t>(p_bytes_to_read);
		memcpy(p_data_out, m_html.data() + m_offset, t_count);
		m_offset += t_count;
		r_bytes_read = static_cast<int>(t_count);
		return true;
	}

	void Cancel() override
	{
	}

private:
	std::string m_html;
	size_t m_offset;

	IMPLEMENT_REFCOUNTING(MCCefSourceResourceHandler);
};

inline CefRefPtr<CefResourceHandler> MCCefCreateSourceResourceHandler(const std::string &p_html)
{
	return new MCCefSourceResourceHandler(p_html);
}

#endif
