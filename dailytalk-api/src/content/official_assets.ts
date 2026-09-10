export type OfficialAssetManifestMetadata = {
  pathId: string;
  packageVersion: number;
  manifestVersion: number;
  sha256: string;
  sizeBytes: number;
  contentType: "application/json";
  downloadPath: string;
  immutable: true;
};

export type OfficialAssetManifest = {
  metadata: OfficialAssetManifestMetadata;
  bytes: Uint8Array;
};

export type OfficialAssetBlobMetadata = {
  sha256: string;
  sizeBytes: number;
  contentType: string;
  immutable: true;
};

export type OfficialAssetBlob = {
  metadata: OfficialAssetBlobMetadata;
  bytes: Uint8Array;
};

export const officialAssetCatalogVersion = 1;

const studentFrFrPhase1V2ManifestBase64 =
  'ewogICJtYW5pZmVzdFZlcnNpb24iOiAxLAogICJwYXRoSWQiOiAic3R1ZGVudC5mci1mci5waGFzZTEiLAogICJwYWNrYWdl' +
  'VmVyc2lvbiI6IDIsCiAgImFzc2V0cyI6IFsKICAgIHsKICAgICAgImFzc2V0SWQiOiAiYXJyaXZhbC52b2NhYnVsYXJ5LTAx' +
  'LmlsbHVzdHJhdGlvbi0wMSIsCiAgICAgICJyZXZpc2lvbklkIjogImFycml2YWwudm9jYWJ1bGFyeS0wMS5yZXZpc2lvbi0w' +
  'MiIsCiAgICAgICJyb2xlIjogImlsbHVzdHJhdGlvbiIsCiAgICAgICJjb250ZW50VHlwZSI6ICJpbWFnZS9wbmciLAogICAg' +
  'ICAic2hhMjU2IjogIjU3MmZiMWIwOTNjOTIxNDA4OGY4M2VkYjcwNTg1OWI2NWM1MzFkMzZlMzNmNGQ4ZGYxNjU5NmMxYjYx' +
  'NDg1OGEiLAogICAgICAic2l6ZUJ5dGVzIjogMTc5LAogICAgICAiZG93bmxvYWRQYXRoIjogIi9hcGkvY29udGVudC9hc3Nl' +
  'dHMvYmxvYnMvNTcyZmIxYjA5M2M5MjE0MDg4ZjgzZWRiNzA1ODU5YjY1YzUzMWQzNmUzM2Y0ZDhkZjE2NTk2YzFiNjE0ODU4' +
  'YSIsCiAgICAgICJyZXF1aXJlZCI6IHRydWUsCiAgICAgICJzb3J0T3JkZXIiOiAwCiAgICB9LAogICAgewogICAgICAiYXNz' +
  'ZXRJZCI6ICJhcnJpdmFsLnZvY2FidWxhcnktMDEucHJvbnVuY2lhdGlvbi0wMSIsCiAgICAgICJyZXZpc2lvbklkIjogImFy' +
  'cml2YWwudm9jYWJ1bGFyeS0wMS5yZXZpc2lvbi0wMiIsCiAgICAgICJyb2xlIjogInByb251bmNpYXRpb24iLAogICAgICAi' +
  'Y29udGVudFR5cGUiOiAiYXVkaW8vd2F2IiwKICAgICAgInNoYTI1NiI6ICI5ZGMzZjZjMGE2YzBiOGI3ZWNiYWQzMGRiNDE1' +
  'YzEwY2ZmOGU1MDRkYjk4ODE0NWFkNzRhZmQwZTkyN2M5YjRjIiwKICAgICAgInNpemVCeXRlcyI6IDQwNDQsCiAgICAgICJk' +
  'b3dubG9hZFBhdGgiOiAiL2FwaS9jb250ZW50L2Fzc2V0cy9ibG9icy85ZGMzZjZjMGE2YzBiOGI3ZWNiYWQzMGRiNDE1YzEw' +
  'Y2ZmOGU1MDRkYjk4ODE0NWFkNzRhZmQwZTkyN2M5YjRjIiwKICAgICAgInJlcXVpcmVkIjogdHJ1ZSwKICAgICAgInNvcnRP' +
  'cmRlciI6IDEKICAgIH0KICBdCn0K';

const arrivalVocabularyIllustrationBase64 =
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAeklEQVR42mP4+uMXTRHDqAWjFmAgrYoTNLQAaDoE0cQCuOkk' +
  '2cFAnunE28FAtulE2sFAienE2MFAoekE7WCg3HT8djBQxXQ8djDgMf3162fEI1x24AsikiwgJw7oZEHUltcQNGoBMXGQF2AO' +
  'R6MWjFowKCwYbXjRxwIAzhXEtrL82OQAAAAASUVORK5CYII=';

const arrivalVocabularyPronunciationBase64 =
  'UklGRsQPAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YaAPAAAAANYKZRSKG24fmh8KHCkVxwsBAR32ZOz85Mbg' +
  'QeB+4xnqS/P+/e0IzhJ3Gv4e2x/0HKAWnw0CAwv4BO4d5kbhEeCi4q3oevH++/oGJRFIGW4e+x/AHQAYag8BBQL6t+9Z5+Xh' +
  'AeDl4Vnnt+8C+gEFag8AGMAd+x9uHkgZJRH6Bv77evGt6KLiEeBG4R3mBO4L+AIDnw2gFvQc2x/+HncazhLtCP79S/MZ6n7j' +
  'QeDG4PzkZOwd9gEBxwspFQocmh9uH4obZRTWCgAAKvWb63bkkuBm4Pbj1+o59P/+4wmcEwQbOh+/H4Ic5xW1DAICE/cy7Ynl' +
  'AuEl4AzjYOlh8v789Qf8EeMZuh7vH14dUxeGDgIEBvnb7rjmkuEF4EDiAOiW8P/6/gVJEKcYGx7/HxsepxhJEP4F//qW8ADo' +
  'QOIF4JLhuObb7gb5AgSGDlMXXh3vH7oe4xn8EfUH/vxh8mDpDOMl4ALhieUy7RP3AgK1DOcVghy/HzofBBucE+MJ//459Nfq' +
  '9uNm4JLgduSb6yr1AADWCmUUihtuH5ofChwpFccLAQEd9mTs/OTG4EHgfuMZ6kvz/v3tCM4Sdxr+Htsf9BygFp8NAgML+ATu' +
  'HeZG4RHgouKt6Hrx/vv6BiURSBluHvsfwB0AGGoPAQUC+rfvWefl4QHg5eFZ57fvAvoBBWoPABjAHfsfbh5IGSUR+gb++3rx' +
  'reii4hHgRuEd5gTuC/gCA58NoBb0HNsf/h53Gs4S7Qj+/UvzGep+40HgxuD85GTsHfYBAccLKRUKHJofbh+KG2UU1goAACr1' +
  'm+t25JLgZuD249fqOfT//uMJnBMEGzofvx+CHOcVtQwCAhP3Mu2J5QLhJeAM42DpYfL+/PUH/BHjGboe7x9eHVMXhg4CBAb5' +
  '2+645pLhBeBA4gDolvD/+v4FSRCnGBse/x8bHqcYSRD+Bf/6lvAA6EDiBeCS4bjm2+4G+QIEhg5TF14d7x+6HuMZ/BH1B/78' +
  'YfJg6QzjJeAC4YnlMu0T9wICtQznFYIcvx86HwQbnBPjCf/+OfTX6vbjZuCS4Hbkm+sq9QAA1gplFIobbh+aHwocKRXHCwEB' +
  'HfZk7PzkxuBB4H7jGepL8/797QjOEnca/h7bH/QcoBafDQIDC/gE7h3mRuER4KLireh68f77+gYlEUgZbh77H8AdABhqDwEF' +
  'Avq371nn5eEB4OXhWee37wL6AQVqDwAYwB37H24eSBklEfoG/vt68a3oouIR4EbhHeYE7gv4AgOfDaAW9BzbH/4edxrOEu0I' +
  '/v1L8xnqfuNB4Mbg/ORk7B32AQHHCykVChyaH24fihtlFNYKAAAq9ZvrduSS4Gbg9uPX6jn0//7jCZwTBBs6H78fghznFbUM' +
  'AgIT9zLtieUC4SXgDONg6WHy/vz1B/wR4xm6Hu8fXh1TF4YOAgQG+dvuuOaS4QXgQOIA6Jbw//r+BUkQpxgbHv8fGx6nGEkQ' +
  '/gX/+pbwAOhA4gXgkuG45tvuBvkCBIYOUxdeHe8fuh7jGfwR9Qf+/GHyYOkM4yXgAuGJ5TLtE/cCArUM5xWCHL8fOh8EG5wT' +
  '4wn//jn01+r242bgkuB25JvrKvUAANYKZRSKG24fmh8KHCkVxwsBAR32ZOz85MbgQeB+4xnqS/P+/e0IzhJ3Gv4e2x/0HKAW' +
  'nw0CAwv4BO4d5kbhEeCi4q3oevH++/oGJRFIGW4e+x/AHQAYag8BBQL6t+9Z5+XhAeDl4Vnnt+8C+gEFag8AGMAd+x9uHkgZ' +
  'JRH6Bv77evGt6KLiEeBG4R3mBO4L+AIDnw2gFvQc2x/+HncazhLtCP79S/MZ6n7jQeDG4PzkZOwd9gEBxwspFQocmh9uH4ob' +
  'ZRTWCgAAKvWb63bkkuBm4Pbj1+o59P/+4wmcEwQbOh+/H4Ic5xW1DAICE/cy7YnlAuEl4AzjYOlh8v789Qf8EeMZuh7vH14d' +
  'UxeGDgIEBvnb7rjmkuEF4EDiAOiW8P/6/gVJEKcYGx7/HxsepxhJEP4F//qW8ADoQOIF4JLhuObb7gb5AgSGDlMXXh3vH7oe' +
  '4xn8EfUH/vxh8mDpDOMl4ALhieUy7RP3AgK1DOcVghy/HzofBBucE+MJ//459Nfq9uNm4JLgduSb6yr1AADWCmUUihtuH5of' +
  'ChwpFccLAQEd9mTs/OTG4EHgfuMZ6kvz/v3tCM4Sdxr+Htsf9BygFp8NAgML+ATuHeZG4RHgouKt6Hrx/vv6BiURSBluHvsf' +
  'wB0AGGoPAQUC+rfvWefl4QHg5eFZ57fvAvoBBWoPABjAHfsfbh5IGSUR+gb++3rxreii4hHgRuEd5gTuC/gCA58NoBb0HNsf' +
  '/h53Gs4S7Qj+/UvzGep+40HgxuD85GTsHfYBAccLKRUKHJofbh+KG2UU1goAACr1m+t25JLgZuD249fqOfT//uMJnBMEGzof' +
  'vx+CHOcVtQwCAhP3Mu2J5QLhJeAM42DpYfL+/PUH/BHjGboe7x9eHVMXhg4CBAb52+645pLhBeBA4gDolvD/+v4FSRCnGBse' +
  '/x8bHqcYSRD+Bf/6lvAA6EDiBeCS4bjm2+4G+QIEhg5TF14d7x+6HuMZ/BH1B/78YfJg6QzjJeAC4YnlMu0T9wICtQznFYIc' +
  'vx86HwQbnBPjCf/+OfTX6vbjZuCS4Hbkm+sq9QAA1gplFIobbh+aHwocKRXHCwEBHfZk7PzkxuBB4H7jGepL8/797QjOEnca' +
  '/h7bH/QcoBafDQIDC/gE7h3mRuER4KLireh68f77+gYlEUgZbh77H8AdABhqDwEFAvq371nn5eEB4OXhWee37wL6AQVqDwAY' +
  'wB37H24eSBklEfoG/vt68a3oouIR4EbhHeYE7gv4AgOfDaAW9BzbH/4edxrOEu0I/v1L8xnqfuNB4Mbg/ORk7B32AQHHCykV' +
  'ChyaH24fihtlFNYKAAAq9ZvrduSS4Gbg9uPX6jn0//7jCZwTBBs6H78fghznFbUMAgIT9zLtieUC4SXgDONg6WHy/vz1B/wR' +
  '4xm6Hu8fXh1TF4YOAgQG+dvuuOaS4QXgQOIA6Jbw//r+BUkQpxgbHv8fGx6nGEkQ/gX/+pbwAOhA4gXgkuG45tvuBvkCBIYO' +
  'UxdeHe8fuh7jGfwR9Qf+/GHyYOkM4yXgAuGJ5TLtE/cCArUM5xWCHL8fOh8EG5wT4wn//jn01+r242bgkuB25JvrKvUAANYK' +
  'ZRSKG24fmh8KHCkVxwsBAR32ZOz85MbgQeB+4xnqS/P+/e0IzhJ3Gv4e2x/0HKAWnw0CAwv4BO4d5kbhEeCi4q3oevH++/oG' +
  'JRFIGW4e+x/AHQAYag8BBQL6t+9Z5+XhAeDl4Vnnt+8C+gEFag8AGMAd+x9uHkgZJRH6Bv77evGt6KLiEeBG4R3mBO4L+AID' +
  'nw2gFvQc2x/+HncazhLtCP79S/MZ6n7jQeDG4PzkZOwd9gEBxwspFQocmh9uH4obZRTWCgAAKvWb63bkkuBm4Pbj1+o59P/+' +
  '4wmcEwQbOh+/H4Ic5xW1DAICE/cy7YnlAuEl4AzjYOlh8v789Qf8EeMZuh7vH14dUxeGDgIEBvnb7rjmkuEF4EDiAOiW8P/6' +
  '/gVJEKcYGx7/HxsepxhJEP4F//qW8ADoQOIF4JLhuObb7gb5AgSGDlMXXh3vH7oe4xn8EfUH/vxh8mDpDOMl4ALhieUy7RP3' +
  'AgK1DOcVghy/HzofBBucE+MJ//459Nfq9uNm4JLgduSb6yr1AADWCmUUihtuH5ofChwpFccLAQEd9mTs/OTG4EHgfuMZ6kvz' +
  '/v3tCM4Sdxr+Htsf9BygFp8NAgML+ATuHeZG4RHgouKt6Hrx/vv6BiURSBluHvsfwB0AGGoPAQUC+rfvWefl4QHg5eFZ57fv' +
  'AvoBBWoPABjAHfsfbh5IGSUR+gb++3rxreii4hHgRuEd5gTuC/gCA58NoBb0HNsf/h53Gs4S7Qj+/UvzGep+40HgxuD85GTs' +
  'HfYBAccLKRUKHJofbh+KG2UU1goAACr1m+t25JLgZuD249fqOfT//uMJnBMEGzofvx+CHOcVtQwCAhP3Mu2J5QLhJeAM42Dp' +
  'YfL+/PUH/BHjGboe7x9eHVMXhg4CBAb52+645pLhBeBA4gDolvD/+v4FSRCnGBse/x8bHqcYSRD+Bf/6lvAA6EDiBeCS4bjm' +
  '2+4G+QIEhg5TF14d7x+6HuMZ/BH1B/78YfJg6QzjJeAC4YnlMu0T9wICtQznFYIcvx86HwQbnBPjCf/+OfTX6vbjZuCS4Hbk' +
  'm+sq9QAA1gplFIobbh+aHwocKRXHCwEBHfZk7PzkxuBB4H7jGepL8/797QjOEnca/h7bH/QcoBafDQIDC/gE7h3mRuER4KLi' +
  'reh68f77+gYlEUgZbh77H8AdABhqDwEFAvq371nn5eEB4OXhWee37wL6AQVqDwAYwB37H24eSBklEfoG/vt68a3oouIR4Ebh' +
  'HeYE7gv4AgOfDaAW9BzbH/4edxrOEu0I/v1L8xnqfuNB4Mbg/ORk7B32AQHHCykVChyaH24fihtlFNYKAAAq9ZvrduSS4Gbg' +
  '9uPX6jn0//7jCZwTBBs6H78fghznFbUMAgIT9zLtieUC4SXgDONg6WHy/vz1B/wR4xm6Hu8fXh1TF4YOAgQG+dvuuOaS4QXg' +
  'QOIA6Jbw//r+BUkQpxgbHv8fGx6nGEkQ/gX/+pbwAOhA4gXgkuG45tvuBvkCBIYOUxdeHe8fuh7jGfwR9Qf+/GHyYOkM4yXg' +
  'AuGJ5TLtE/cCArUM5xWCHL8fOh8EG5wT4wn//jn01+r242bgkuB25JvrKvUAANYKZRSKG24fmh8KHCkVxwsBAR32ZOz85Mbg' +
  'QeB+4xnqS/P+/e0IzhJ3Gv4e2x/0HKAWnw0CAwv4BO4d5kbhEeCi4q3oevH++/oGJRFIGW4e+x/AHQAYag8BBQL6t+9Z5+Xh' +
  'AeDl4Vnnt+8C+gEFag8AGMAd+x9uHkgZJRH6Bv77evGt6KLiEeBG4R3mBO4L+AIDnw2gFvQc2x/+HncazhLtCP79S/MZ6n7j' +
  'QeDG4PzkZOwd9gEBxwspFQocmh9uH4obZRTWCgAAKvWb63bkkuBm4Pbj1+o59P/+4wmcEwQbOh+/H4Ic5xW1DAICE/cy7Ynl' +
  'AuEl4AzjYOlh8v789Qf8EeMZuh7vH14dUxeGDgIEBvnb7rjmkuEF4EDiAOiW8P/6/gVJEKcYGx7/HxsepxhJEP4F//qW8ADo' +
  'QOIF4JLhuObb7gb5AgSGDlMXXh3vH7oe4xn8EfUH/vxh8mDpDOMl4ALhieUy7RP3AgK1DOcVghy/HzofBBucE+MJ//459Nfq' +
  '9uNm4JLgduSb6yr1';

const studentFrFrPhase1V3ManifestBase64 =
  'ewogICJtYW5pZmVzdFZlcnNpb24iOiAxLAogICJwYXRoSWQiOiAic3R1ZGVudC5mci1mci5waGFzZTEiLAogICJwYWNrYWdl' +
  'VmVyc2lvbiI6IDMsCiAgImFzc2V0cyI6IFsKICAgIHsKICAgICAgImFzc2V0SWQiOiAiYXJyaXZhbC52b2NhYnVsYXJ5LTAx' +
  'LmlsbHVzdHJhdGlvbi0wMiIsCiAgICAgICJyZXZpc2lvbklkIjogImFycml2YWwudm9jYWJ1bGFyeS0wMS5yZXZpc2lvbi0w' +
  'MyIsCiAgICAgICJyb2xlIjogImlsbHVzdHJhdGlvbiIsCiAgICAgICJjb250ZW50VHlwZSI6ICJpbWFnZS9wbmciLAogICAg' +
  'ICAic2hhMjU2IjogIjg0ZWY4YTE1NzQzNDc5MzU4ZTJmMTdmYTVkN2RkZmFjN2YxMGU3ZTU1MWFhNTNmMDhjMDE3MzFhODI1' +
  'NzYyNmEiLAogICAgICAic2l6ZUJ5dGVzIjogMzQwLAogICAgICAiZG93bmxvYWRQYXRoIjogIi9hcGkvY29udGVudC9hc3Nl' +
  'dHMvYmxvYnMvODRlZjhhMTU3NDM0NzkzNThlMmYxN2ZhNWQ3ZGRmYWM3ZjEwZTdlNTUxYWE1M2YwOGMwMTczMWE4MjU3NjI2' +
  'YSIsCiAgICAgICJyZXF1aXJlZCI6IHRydWUsCiAgICAgICJzb3J0T3JkZXIiOiAwCiAgICB9LAogICAgewogICAgICAiYXNz' +
  'ZXRJZCI6ICJhcnJpdmFsLnZvY2FidWxhcnktMDEucHJvbnVuY2lhdGlvbi0wMiIsCiAgICAgICJyZXZpc2lvbklkIjogImFy' +
  'cml2YWwudm9jYWJ1bGFyeS0wMS5yZXZpc2lvbi0wMyIsCiAgICAgICJyb2xlIjogInByb251bmNpYXRpb24iLAogICAgICAi' +
  'Y29udGVudFR5cGUiOiAiYXVkaW8vd2F2IiwKICAgICAgInNoYTI1NiI6ICI2NGEyODlkNTc1MzgxYmNjMjQ4MTM5ZmJkNDhm' +
  'MTU1NDljNWViY2FiMTE3MjM4MjAwMTYzZjBiY2VlNDVkODEzIiwKICAgICAgInNpemVCeXRlcyI6IDU2NDQsCiAgICAgICJk' +
  'b3dubG9hZFBhdGgiOiAiL2FwaS9jb250ZW50L2Fzc2V0cy9ibG9icy82NGEyODlkNTc1MzgxYmNjMjQ4MTM5ZmJkNDhmMTU1' +
  'NDljNWViY2FiMTE3MjM4MjAwMTYzZjBiY2VlNDVkODEzIiwKICAgICAgInJlcXVpcmVkIjogdHJ1ZSwKICAgICAgInNvcnRP' +
  'cmRlciI6IDEKICAgIH0sCiAgICB7CiAgICAgICJhc3NldElkIjogImFycml2YWwudm9jYWJ1bGFyeS0wMy5pbGx1c3RyYXRp' +
  'b24tMDEiLAogICAgICAicmV2aXNpb25JZCI6ICJhcnJpdmFsLnZvY2FidWxhcnktMDMucmV2aXNpb24tMDEiLAogICAgICAi' +
  'cm9sZSI6ICJpbGx1c3RyYXRpb24iLAogICAgICAiY29udGVudFR5cGUiOiAiaW1hZ2UvcG5nIiwKICAgICAgInNoYTI1NiI6' +
  'ICI1NzJmYjFiMDkzYzkyMTQwODhmODNlZGI3MDU4NTliNjVjNTMxZDM2ZTMzZjRkOGRmMTY1OTZjMWI2MTQ4NThhIiwKICAg' +
  'ICAgInNpemVCeXRlcyI6IDE3OSwKICAgICAgImRvd25sb2FkUGF0aCI6ICIvYXBpL2NvbnRlbnQvYXNzZXRzL2Jsb2JzLzU3' +
  'MmZiMWIwOTNjOTIxNDA4OGY4M2VkYjcwNTg1OWI2NWM1MzFkMzZlMzNmNGQ4ZGYxNjU5NmMxYjYxNDg1OGEiLAogICAgICAi' +
  'cmVxdWlyZWQiOiBmYWxzZSwKICAgICAgInNvcnRPcmRlciI6IDAKICAgIH0sCiAgICB7CiAgICAgICJhc3NldElkIjogImFy' +
  'cml2YWwudm9jYWJ1bGFyeS0wMy5wcm9udW5jaWF0aW9uLTAxIiwKICAgICAgInJldmlzaW9uSWQiOiAiYXJyaXZhbC52b2Nh' +
  'YnVsYXJ5LTAzLnJldmlzaW9uLTAxIiwKICAgICAgInJvbGUiOiAicHJvbnVuY2lhdGlvbiIsCiAgICAgICJjb250ZW50VHlw' +
  'ZSI6ICJhdWRpby93YXYiLAogICAgICAic2hhMjU2IjogIjlkYzNmNmMwYTZjMGI4YjdlY2JhZDMwZGI0MTVjMTBjZmY4ZTUw' +
  'NGRiOTg4MTQ1YWQ3NGFmZDBlOTI3YzliNGMiLAogICAgICAic2l6ZUJ5dGVzIjogNDA0NCwKICAgICAgImRvd25sb2FkUGF0' +
  'aCI6ICIvYXBpL2NvbnRlbnQvYXNzZXRzL2Jsb2JzLzlkYzNmNmMwYTZjMGI4YjdlY2JhZDMwZGI0MTVjMTBjZmY4ZTUwNGRi' +
  'OTg4MTQ1YWQ3NGFmZDBlOTI3YzliNGMiLAogICAgICAicmVxdWlyZWQiOiBmYWxzZSwKICAgICAgInNvcnRPcmRlciI6IDEK' +
  'ICAgIH0sCiAgICB7CiAgICAgICJhc3NldElkIjogImFycml2YWwuZGlhbG9ndWUtMDMuaWxsdXN0cmF0aW9uLTAxIiwKICAg' +
  'ICAgInJldmlzaW9uSWQiOiAiYXJyaXZhbC5kaWFsb2d1ZS0wMy5yZXZpc2lvbi0wMSIsCiAgICAgICJyb2xlIjogImlsbHVz' +
  'dHJhdGlvbiIsCiAgICAgICJjb250ZW50VHlwZSI6ICJpbWFnZS9wbmciLAogICAgICAic2hhMjU2IjogIjU3MmZiMWIwOTNj' +
  'OTIxNDA4OGY4M2VkYjcwNTg1OWI2NWM1MzFkMzZlMzNmNGQ4ZGYxNjU5NmMxYjYxNDg1OGEiLAogICAgICAic2l6ZUJ5dGVz' +
  'IjogMTc5LAogICAgICAiZG93bmxvYWRQYXRoIjogIi9hcGkvY29udGVudC9hc3NldHMvYmxvYnMvNTcyZmIxYjA5M2M5MjE0' +
  'MDg4ZjgzZWRiNzA1ODU5YjY1YzUzMWQzNmUzM2Y0ZDhkZjE2NTk2YzFiNjE0ODU4YSIsCiAgICAgICJyZXF1aXJlZCI6IGZh' +
  'bHNlLAogICAgICAic29ydE9yZGVyIjogMAogICAgfSwKICAgIHsKICAgICAgImFzc2V0SWQiOiAiYXJyaXZhbC5zcGVlY2gt' +
  'MDMucHJvbnVuY2lhdGlvbi0wMSIsCiAgICAgICJyZXZpc2lvbklkIjogImFycml2YWwuc3BlZWNoLTAzLnJldmlzaW9uLTAx' +
  'IiwKICAgICAgInJvbGUiOiAicHJvbnVuY2lhdGlvbiIsCiAgICAgICJjb250ZW50VHlwZSI6ICJhdWRpby93YXYiLAogICAg' +
  'ICAic2hhMjU2IjogIjlkYzNmNmMwYTZjMGI4YjdlY2JhZDMwZGI0MTVjMTBjZmY4ZTUwNGRiOTg4MTQ1YWQ3NGFmZDBlOTI3' +
  'YzliNGMiLAogICAgICAic2l6ZUJ5dGVzIjogNDA0NCwKICAgICAgImRvd25sb2FkUGF0aCI6ICIvYXBpL2NvbnRlbnQvYXNz' +
  'ZXRzL2Jsb2JzLzlkYzNmNmMwYTZjMGI4YjdlY2JhZDMwZGI0MTVjMTBjZmY4ZTUwNGRiOTg4MTQ1YWQ3NGFmZDBlOTI3Yzli' +
  'NGMiLAogICAgICAicmVxdWlyZWQiOiBmYWxzZSwKICAgICAgInNvcnRPcmRlciI6IDAKICAgIH0sCiAgICB7CiAgICAgICJh' +
  'c3NldElkIjogImFycml2YWwudm9jYWJ1bGFyeS0wNC5pbGx1c3RyYXRpb24tMDEiLAogICAgICAicmV2aXNpb25JZCI6ICJh' +
  'cnJpdmFsLnZvY2FidWxhcnktMDQucmV2aXNpb24tMDEiLAogICAgICAicm9sZSI6ICJpbGx1c3RyYXRpb24iLAogICAgICAi' +
  'Y29udGVudFR5cGUiOiAiaW1hZ2UvcG5nIiwKICAgICAgInNoYTI1NiI6ICI1NzJmYjFiMDkzYzkyMTQwODhmODNlZGI3MDU4' +
  'NTliNjVjNTMxZDM2ZTMzZjRkOGRmMTY1OTZjMWI2MTQ4NThhIiwKICAgICAgInNpemVCeXRlcyI6IDE3OSwKICAgICAgImRv' +
  'd25sb2FkUGF0aCI6ICIvYXBpL2NvbnRlbnQvYXNzZXRzL2Jsb2JzLzU3MmZiMWIwOTNjOTIxNDA4OGY4M2VkYjcwNTg1OWI2' +
  'NWM1MzFkMzZlMzNmNGQ4ZGYxNjU5NmMxYjYxNDg1OGEiLAogICAgICAicmVxdWlyZWQiOiBmYWxzZSwKICAgICAgInNvcnRP' +
  'cmRlciI6IDAKICAgIH0sCiAgICB7CiAgICAgICJhc3NldElkIjogImFycml2YWwuc3BlZWNoLTA0LnByb251bmNpYXRpb24t' +
  'MDEiLAogICAgICAicmV2aXNpb25JZCI6ICJhcnJpdmFsLnNwZWVjaC0wNC5yZXZpc2lvbi0wMSIsCiAgICAgICJyb2xlIjog' +
  'InByb251bmNpYXRpb24iLAogICAgICAiY29udGVudFR5cGUiOiAiYXVkaW8vd2F2IiwKICAgICAgInNoYTI1NiI6ICI5ZGMz' +
  'ZjZjMGE2YzBiOGI3ZWNiYWQzMGRiNDE1YzEwY2ZmOGU1MDRkYjk4ODE0NWFkNzRhZmQwZTkyN2M5YjRjIiwKICAgICAgInNp' +
  'emVCeXRlcyI6IDQwNDQsCiAgICAgICJkb3dubG9hZFBhdGgiOiAiL2FwaS9jb250ZW50L2Fzc2V0cy9ibG9icy85ZGMzZjZj' +
  'MGE2YzBiOGI3ZWNiYWQzMGRiNDE1YzEwY2ZmOGU1MDRkYjk4ODE0NWFkNzRhZmQwZTkyN2M5YjRjIiwKICAgICAgInJlcXVp' +
  'cmVkIjogZmFsc2UsCiAgICAgICJzb3J0T3JkZXIiOiAwCiAgICB9CiAgXQp9Cg==';

const arrivalReferenceV3IllustrationBase64 =
  'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAABG0lEQVR42u2a0Q3DIAxEE8QyzMIWDJYtmIVJKvWv/asqWqIA' +
  'h8HK+ZdEuhefjUmyP56vTXOYTXkQgAAEIMDcsKUFF+JqWtPhaSFFFjpPnGScm5kWIgABCLB6GwX2vhEd2Qro/l0Fkhgx9YMG' +
  'LTtI/d9n/H2NCxGSBwNXnw5fUpYtQfJg4Oqrhqt+BiOsHs5g5NVjGTA10FaOCxWxylECsit97m12EYc5AhCAAFoB+jsgpBfT' +
  'Qh1JmD9O9wxkPYMgMgNtDCj1GAvVMgDVDxmnXYgljGwJMk7DDvXp8NmZXeAwAG6jbUfKVTJwZXdT8GZuqFbuxAQYEXU1IPb1' +
  '+3oJ0UK6LDT9o/ctM7Dgbyss4pVi54+vBCAAAQjQE2/lknttBCb+cQAAAABJRU5ErkJggg==';

const arrivalReferenceV3PronunciationBase64 =
  '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' +
  'BwHxALcAZwATAM3/nP+I/47/qP/L/+z/AQAIAA==';

const studentFrFrPhase1V2ManifestMetadata: OfficialAssetManifestMetadata = {
  pathId: "student.fr-fr.phase1",
  packageVersion: 2,
  manifestVersion: 1,
  sha256: "d9ac2ce729a71cbacab669bb971c9511e340e0f7a140299ad80d5faee540aac9",
  sizeBytes: 1029,
  contentType: "application/json",
  downloadPath: "/api/content/assets/manifests/student.fr-fr.phase1/2",
  immutable: true,
};

const arrivalVocabularyIllustrationMetadata: OfficialAssetBlobMetadata = {
  sha256: "572fb1b093c9214088f83edb705859b65c531d36e33f4d8df16596c1b614858a",
  sizeBytes: 179,
  contentType: "image/png",
  immutable: true,
};

const arrivalVocabularyPronunciationMetadata: OfficialAssetBlobMetadata = {
  sha256: "9dc3f6c0a6c0b8b7ecbad30db415c10cff8e504db988145ad74afd0e927c9b4c",
  sizeBytes: 4044,
  contentType: "audio/wav",
  immutable: true,
};

const studentFrFrPhase1V3ManifestMetadata: OfficialAssetManifestMetadata = {
  pathId: "student.fr-fr.phase1",
  packageVersion: 3,
  manifestVersion: 1,
  sha256: "bccf2da598c07ec04ddebf66ea0dc665bc7237b5928cefa0082c888a231a7e80",
  sizeBytes: 3790,
  contentType: "application/json",
  downloadPath: "/api/content/assets/manifests/student.fr-fr.phase1/3",
  immutable: true,
};

const arrivalReferenceV3IllustrationMetadata: OfficialAssetBlobMetadata = {
  sha256: "84ef8a15743479358e2f17fa5d7ddfac7f10e7e551aa53f08c01731a8257626a",
  sizeBytes: 340,
  contentType: "image/png",
  immutable: true,
};

const arrivalReferenceV3PronunciationMetadata: OfficialAssetBlobMetadata = {
  sha256: "64a289d575381bcc248139fbd48f15549c5ebcab117238200163f0bcee45d813",
  sizeBytes: 5644,
  contentType: "audio/wav",
  immutable: true,
};

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

const manifests: OfficialAssetManifest[] = [
  {
    metadata: studentFrFrPhase1V2ManifestMetadata,
    bytes: decodeBase64(studentFrFrPhase1V2ManifestBase64),
  },
  {
    metadata: studentFrFrPhase1V3ManifestMetadata,
    bytes: decodeBase64(studentFrFrPhase1V3ManifestBase64),
  },
];

const blobs: OfficialAssetBlob[] = [
  {
    metadata: arrivalVocabularyIllustrationMetadata,
    bytes: decodeBase64(arrivalVocabularyIllustrationBase64),
  },
  {
    metadata: arrivalVocabularyPronunciationMetadata,
    bytes: decodeBase64(arrivalVocabularyPronunciationBase64),
  },
  {
    metadata: arrivalReferenceV3IllustrationMetadata,
    bytes: decodeBase64(arrivalReferenceV3IllustrationBase64),
  },
  {
    metadata: arrivalReferenceV3PronunciationMetadata,
    bytes: decodeBase64(arrivalReferenceV3PronunciationBase64),
  },
];

export function listOfficialAssetManifests(): OfficialAssetManifestMetadata[] {
  return manifests
    .map((item) => ({ ...item.metadata }))
    .sort((a, b) => {
      const pathOrder = a.pathId.localeCompare(b.pathId);
      if (pathOrder !== 0) return pathOrder;
      return b.packageVersion - a.packageVersion;
    });
}

export function findOfficialAssetManifest(
  pathId: string,
  packageVersion: number,
): OfficialAssetManifest | null {
  const found = manifests.find(
    (item) =>
      item.metadata.pathId === pathId &&
      item.metadata.packageVersion === packageVersion,
  );
  if (!found) return null;
  return {
    metadata: { ...found.metadata },
    bytes: found.bytes.slice(),
  };
}

export function findOfficialAssetBlob(sha256: string): OfficialAssetBlob | null {
  const normalized = sha256.trim().toLowerCase();
  const found = blobs.find((item) => item.metadata.sha256 === normalized);
  if (!found) return null;
  return {
    metadata: { ...found.metadata },
    bytes: found.bytes.slice(),
  };
}

export function officialAssetEtag(sha256: string): string {
  return `"sha256-${sha256}"`;
}
