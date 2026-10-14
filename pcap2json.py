#!/usr/bin/env python3
import os
import sys
import json
import time
import collections
import subprocess

FIELDS = [
    'frame.number', 'frame.time_epoch', 'frame.len', 'frame.protocols',
    'eth.src', 'eth.dst',
    'ip.src', 'ip.dst', 'ip.proto', 'ip.ttl',
    '_ws.col.Protocol', '_ws.col.Info',
    'tcp.srcport', 'tcp.dstport', 'tcp.flags', 'tcp.seq', 'tcp.ack',
    'tcp.stream', 'tcp.len',
    'udp.srcport', 'udp.dstport', 'udp.stream', 'udp.length',
    'http.request.method', 'http.host', 'http.request.uri',
    'http.request.full_uri', 'http.user_agent', 'http.referer', 'http.cookie',
    'http.content_type', 'http.content_length',
    'http.request.line', 'http.response.code', 'http.response.line',
    'http.file_data',
    'dns.qry.name', 'dns.a', 'dns.aaaa', 'dns.cname', 'dns.flags.response',
    'tls.handshake.extensions_server_name', 'tls.record.version',
    'tls.handshake.type',
    'data.text', 'data.data',
]

KEYS = [
    'frame_no', 'time', 'len', 'protocols',
    'eth_src', 'eth_dst',
    'ip_src', 'ip_dst', 'ip_proto', 'ip_ttl',
    'proto', 'info',
    'tcp_sport', 'tcp_dport', 'tcp_flags', 'tcp_seq', 'tcp_ack',
    'tcp_stream', 'tcp_len',
    'udp_sport', 'udp_dport', 'udp_stream', 'udp_len',
    'http_method', 'http_host', 'http_uri', 'http_full_uri',
    'http_ua', 'http_referer', 'http_cookie',
    'http_ctype', 'http_clen',
    'http_req_line', 'http_code', 'http_resp_line',
    'http_file_data',
    'dns_name', 'dns_a', 'dns_aaaa', 'dns_cname', 'dns_resp',
    'tls_sni', 'tls_ver', 'tls_hs_type',
    'data_text', 'data_data',
]


def f1(v):
    return v.split(',')[0] if v else ''


def to_int(v, d=0):
    try:
        return int(v)
    except Exception:
        return d


def to_float(v, d=0.0):
    try:
        return float(v)
    except Exception:
        return d


def hex_to_payload(hexstr):
    if not hexstr:
        return None
    h = ''.join(c for c in hexstr if c in '0123456789abcdefABCDEF')
    if len(h) % 2:
        h = h[:-1]
    if not h:
        return None
    try:
        raw = bytes.fromhex(h)
    except Exception:
        return None
    try:
        txt = raw.decode('utf-8')
        enc = 'utf-8'
        ok = True
    except Exception:
        txt = raw.decode('latin-1')
        enc = 'latin-1'
        ok = False
    printable = sum(1 for b in raw if 32 <= b < 127 or b in (9, 10, 13))
    ratio = round(printable / len(raw), 4) if raw else 0.0
    return {
        'size': len(raw),
        'encoding': enc,
        'utf8_valid': ok,
        'printable_ratio': ratio,
        'text': txt,
        'hex': h.lower(),
    }


def run_tshark(pcap):
    args = ['tshark', '-r', pcap, '-n', '-T', 'fields',
            '-E', 'separator=/t', '-E', 'occurrence=a', '-E', 'aggregator=,']
    for f in FIELDS:
        args += ['-e', f]
    res = subprocess.run(args, capture_output=True, text=True, errors='replace')
    return res.stdout


def parse_row(raw):
    parts = raw.split('\t')
    while len(parts) < len(KEYS):
        parts.append('')
    return dict(zip(KEYS, parts))


def build_packet(r):
    pkt = {
        'no': to_int(r['frame_no']),
        'time': to_float(r['time']),
        'len': to_int(r['len']),
        'protocols': r['protocols'],
        'eth': {'src': r['eth_src'], 'dst': r['eth_dst']},
        'ip': {
            'src': r['ip_src'],
            'dst': r['ip_dst'],
            'proto_num': to_int(r['ip_proto']),
            'ttl': to_int(r['ip_ttl']),
        },
        'proto': r['proto'] or 'UNKNOWN',
        'info': r['info'],
    }

    if r['tcp_sport'] or r['tcp_dport']:
        t = {}
        if r['tcp_sport']:
            t['sport'] = to_int(f1(r['tcp_sport']))
        if r['tcp_dport']:
            t['dport'] = to_int(f1(r['tcp_dport']))
        if r['tcp_flags']:
            t['flags'] = r['tcp_flags']
        if r['tcp_seq']:
            t['seq'] = r['tcp_seq']
        if r['tcp_ack']:
            t['ack'] = r['tcp_ack']
        if r['tcp_len']:
            t['data_len'] = to_int(f1(r['tcp_len']))
        if r['tcp_stream']:
            t['stream'] = to_int(f1(r['tcp_stream']))
        pkt['tcp'] = t
        if 'sport' in t:
            pkt['src_port'] = t['sport']
        if 'dport' in t:
            pkt['dst_port'] = t['dport']

    if r['udp_sport'] or r['udp_dport']:
        u = {}
        if r['udp_sport']:
            u['sport'] = to_int(f1(r['udp_sport']))
        if r['udp_dport']:
            u['dport'] = to_int(f1(r['udp_dport']))
        if r['udp_len']:
            u['length'] = to_int(f1(r['udp_len']))
        if r['udp_stream']:
            u['stream'] = to_int(f1(r['udp_stream']))
        pkt['udp'] = u
        if 'src_port' not in pkt and 'sport' in u:
            pkt['src_port'] = u['sport']
        if 'dst_port' not in pkt and 'dport' in u:
            pkt['dst_port'] = u['dport']

    if (r['http_method'] or r['http_host'] or r['http_uri']
            or r['http_code'] or r['http_req_line'] or r['http_resp_line']):
        h = {}
        if r['http_method']:
            h['method'] = r['http_method']
        if r['http_host']:
            h['host'] = f1(r['http_host'])
        if r['http_uri']:
            h['uri'] = f1(r['http_uri'])
        if r['http_full_uri']:
            h['full_uri'] = f1(r['http_full_uri'])
        if r['http_ua']:
            h['user_agent'] = r['http_ua']
        if r['http_referer']:
            h['referer'] = f1(r['http_referer'])
        if r['http_cookie']:
            h['cookie'] = r['http_cookie']
        if r['http_ctype']:
            h['content_type'] = f1(r['http_ctype'])
        if r['http_clen']:
            h['content_length'] = to_int(f1(r['http_clen']))
        if r['http_req_line']:
            h['request_lines'] = r['http_req_line'].split(',')
        if r['http_resp_line']:
            h['response_lines'] = r['http_resp_line'].split(',')
        if r['http_code']:
            h['status_code'] = to_int(f1(r['http_code']))
        pkt['http'] = h

    if r['dns_name'] or r['dns_a'] or r['dns_aaaa'] or r['dns_cname']:
        d = {}
        if r['dns_name']:
            d['name'] = f1(r['dns_name'])
        if r['dns_a']:
            d['a'] = r['dns_a'].split(',')
        if r['dns_aaaa']:
            d['aaaa'] = r['dns_aaaa'].split(',')
        if r['dns_cname']:
            d['cname'] = r['dns_cname'].split(',')
        if r['dns_resp']:
            d['is_response'] = (f1(r['dns_resp']) == '1')
        pkt['dns'] = d

    if r['tls_sni'] or r['tls_ver'] or r['tls_hs_type']:
        t = {}
        if r['tls_sni']:
            t['sni'] = f1(r['tls_sni'])
        if r['tls_ver']:
            t['record_version'] = r['tls_ver']
        if r['tls_hs_type']:
            t['handshake_type'] = r['tls_hs_type']
        pkt['tls'] = t

    payload = None
    if r['http_file_data']:
        payload = hex_to_payload(f1(r['http_file_data']))
    elif r['data_data']:
        payload = hex_to_payload(r['data_data'])
    elif r['data_text']:
        txt = r['data_text']
        payload = {
            'size': len(txt),
            'encoding': 'text',
            'utf8_valid': True,
            'printable_ratio': 1.0,
            'text': txt,
            'hex': txt.encode('utf-8', 'replace').hex(),
        }
    if payload:
        pkt['payload'] = payload

    return pkt


def main():
    if len(sys.argv) < 3:
        print("Usage: pcap2json.py <pcap> <json_out> [mode] [iface] [gateway] [subnet]",
              file=sys.stderr)
        sys.exit(1)

    pcap = sys.argv[1]
    json_out = sys.argv[2]
    mode = sys.argv[3] if len(sys.argv) > 3 else ''
    iface = sys.argv[4] if len(sys.argv) > 4 else ''
    gateway = sys.argv[5] if len(sys.argv) > 5 else ''
    subnet = sys.argv[6] if len(sys.argv) > 6 else ''

    tsv = run_tshark(pcap)

    packets = []
    proto_counter = collections.Counter()
    src_counter = collections.Counter()
    dst_counter = collections.Counter()
    streams = collections.defaultdict(lambda: {
        'pkts': 0, 'bytes': 0, 'srcs': set(), 'dsts': set(),
        'protos': set(), 'sport': None, 'dport': None,
    })
    http_requests = []
    http_responses = []
    dns_queries = []
    tls_snis_set = set()

    for raw in tsv.splitlines():
        if not raw:
            continue
        r = parse_row(raw)
        pkt = build_packet(r)
        packets.append(pkt)

        proto_counter[pkt['proto']] += 1
        if pkt['ip']['src']:
            src_counter[pkt['ip']['src']] += 1
        if pkt['ip']['dst']:
            dst_counter[pkt['ip']['dst']] += 1

        h = pkt.get('http')
        if h:
            if h.get('method'):
                http_requests.append({
                    'no': pkt['no'],
                    'src': pkt['ip']['src'],
                    'dst': pkt['ip']['dst'],
                    'method': h['method'],
                    'host': h.get('host', ''),
                    'uri': h.get('uri', ''),
                    'full_uri': h.get('full_uri', ''),
                    'user_agent': h.get('user_agent', ''),
                    'referer': h.get('referer', ''),
                    'content_type': h.get('content_type', ''),
                })
            if h.get('status_code'):
                http_responses.append({
                    'no': pkt['no'],
                    'src': pkt['ip']['src'],
                    'dst': pkt['ip']['dst'],
                    'status': h['status_code'],
                })

        d = pkt.get('dns')
        if d and not d.get('is_response') and d.get('name'):
            dns_queries.append({
                'no': pkt['no'],
                'src': pkt['ip']['src'],
                'name': d['name'],
            })

        t = pkt.get('tls')
        if t and t.get('sni'):
            tls_snis_set.add(t['sni'])

        skey = None
        if 'tcp' in pkt and 'stream' in pkt['tcp']:
            skey = f"TCP {pkt['tcp']['stream']}"
        elif 'udp' in pkt and 'stream' in pkt['udp']:
            skey = f"UDP {pkt['udp']['stream']}"
        if skey:
            s = streams[skey]
            s['pkts'] += 1
            s['bytes'] += pkt['len']
            s['protos'].add(pkt['proto'])
            if pkt['ip']['src']:
                s['srcs'].add(pkt['ip']['src'])
            if pkt['ip']['dst']:
                s['dsts'].add(pkt['ip']['dst'])
            if 'src_port' in pkt and s['sport'] is None:
                s['sport'] = pkt['src_port']
            if 'dst_port' in pkt and s['dport'] is None:
                s['dport'] = pkt['dst_port']

    streams_out = []
    for k, v in streams.items():
        streams_out.append({
            'id': k,
            'packets': v['pkts'],
            'bytes': v['bytes'],
            'srcs': sorted(v['srcs']),
            'dsts': sorted(v['dsts']),
            'protos': sorted(v['protos']),
            'sport': v['sport'],
            'dport': v['dport'],
        })
    streams_out.sort(key=lambda x: -x['bytes'])

    duration = (packets[-1]['time'] - packets[0]['time']) if len(packets) > 1 else 0
    total_bytes = sum(p['len'] for p in packets)

    out = {
        'meta': {
            'pcap_file': os.path.basename(pcap),
            'total': len(packets),
            'total_bytes': total_bytes,
            'duration_sec': round(duration, 3),
            'mode': mode,
            'interface': iface,
            'gateway': gateway,
            'subnet': subnet,
            'generated': time.strftime('%Y-%m-%d %H:%M:%S'),
        },
        'stats': {
            'protocols': [{'proto': p, 'count': c} for p, c in proto_counter.most_common()],
            'top_src': [{'ip': ip, 'count': c} for ip, c in src_counter.most_common(20)],
            'top_dst': [{'ip': ip, 'count': c} for ip, c in dst_counter.most_common(20)],
        },
        'http_requests': http_requests,
        'http_responses': http_responses,
        'dns_queries': dns_queries,
        'tls_snis': sorted(tls_snis_set),
        'streams': streams_out,
        'packets': packets,
    }

    with open(json_out, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False)

    print(f"  ✔ {len(packets)} paket → JSON")


if __name__ == '__main__':
    main()