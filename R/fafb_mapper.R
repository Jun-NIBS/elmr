#' Convert coordinates between different FAFB assemblies
#'
#' @param xyz xyz coordinates (in nm)
#' @param from,to Assemblies to convert between e.g. \code{"v12"}, \code{"v13"},
#'   \code{"v14"}.
#' @param baseurl path to Janelia \code{tem-services} server (not externally
#'   visible at the moment)
#' @param method Whether to try and convert multiple coordinates at once.
#'   Defaults to 'single'. The 'many' method currently appears fragile and not
#'   much faster.
#' @param ... Additional arguments (currently unused)
#'
#' @description \code{fafb_world_mapper} provides a low-level interface to map
#'   coordinates based on the \code{tem-services} API available from inside the
#'   HHMI Janelia VPN. The hope is to make this service generally available in
#'   due course.
#'
#'   End users are not presently expected to use this directly. Instead they
#'   should use \code{xform_brain} to transform data. See examples.
#' @importFrom jsonlite fromJSON
#' @importFrom httr GET content http_error
#' @importFrom plyr aaply
#' @examples
#' \dontrun{
#' FAFB12.surf=xform_brain(JFRC2013.surf, sample = JFRC2013, reference = FAFB12)
#' FAFB13.surf=xform_brain(JFRC2013.surf, sample=JFRC2013, ref=FAFB13)
#' # current assembly
#' FAFB.surf=xform_brain(JFRC2013.surf, sample=JFRC2013, ref=FAFB)
#' }
fafb_world_mapper <- function(xyz, from, to, baseurl="http://tem-services.int.janelia.org:8080/render-ws/v1/owner/flyTEM/project/FAFB00/stack",
                              method=c('single', 'many'), ...) {
  method=match.arg(method)
  assemblies=c("v12_align_tps", "v13_align_tps", "v14_align_tps_20170818")
  from=match.arg(from, choices = assemblies)
  to=match.arg(to, choices = assemblies)
  if(is.data.frame(xyz)) {
    xyz=as.matrix(xyz)
  } else if(!is.matrix(xyz)){
    if(length(xyz)==3) xyz=matrix(xyz, ncol=3)
    else stop("Unrecognised form of xyz input")
  }
  try_map_1 <- function(...) {
    tt=try(map_1(...))
    if(inherits(tt,'try-error')) rep(NA_real_, 3L) else tt
  }
  if(method=="many") {
    res=map_many(xyz, from=from, to=to, baseurl=baseurl, ...)
  } else {
    res=aaply(xyz, 1, try_map_1, from=from, to=to, baseurl=baseurl,
        .progress = ifelse(interactive()&&nrow(xyz)>1, 'text', 'none'), ...)
  }
  dimnames(res)=list(NULL, c("X","Y","Z"))
  res
}

map_1 <- function(xyz, from, to, baseurl, ...) {
  # /v12_align_tps/z/3864/world-to-local-coordinates/95335,47208.5
  # stack, z, x, y
  subpath1=sprintf("/%s/z/%d/world-to-local-coordinates/%f,%f",
                   from, as.integer(xyz[3]), xyz[1], xyz[2])
  res1_raw=httr::GET(paste0(baseurl, subpath1))
  if(http_error(res1_raw)){
    stop("Failed to transform points with query: ", subpath1)
  }
  res1=fromJSON(content(res1_raw, as='text', encoding='UTF-8'), simplifyVector = T)
  # v13_align_tps/tile/150126171511052023.3864.0/local-to-world-coordinates/1221.9181157357234,1370.8960213087994
  # stack, tile, x, y
  subpath2=sprintf("/%s/tile/%s/local-to-world-coordinates/%f,%f",
                   to, res1$tileId[1], res1$local[[1]][1], res1$local[[1]][2])
  res2_raw=httr::GET(paste0(baseurl, subpath2))
  if(http_error(res2_raw)){
    stop("Failed to transform points with query: ", subpath2)
  }
  res2=fromJSON(content(res2_raw, as='text', encoding='UTF-8'), simplifyVector = T)
  unlist(res2$world)
}

map_many <- function(xyz, from, to, baseurl) {
  if(!identical(ncol(xyz), 3L))
    stop("I need an Nx3 matrix!")
  body=lapply(1:nrow(xyz), function(r) list(world=xyz[r,]))

  assemblies=c("v12_align_tps", "v13_align_tps", "v14_align_tps_20170818")
  from=match.arg(from, choices = assemblies)
  to=match.arg(to, choices = assemblies)

  subpath1=sprintf("/%s/world-to-local-coordinates", from)
  res1_raw=httr::PUT(paste0(baseurl, subpath1), body = body, encode="json")
  # what we get back is not in the same form as what we need for the next query
  res1_list=unlist(content(res1_raw, simplifyVector=T, simplifyDataFrame=F), recursive = F)

  subpath2=sprintf("/%s/local-to-world-coordinates", to)
  res2_raw=httr::PUT(paste0(baseurl, subpath2), body = res1_list, encode="json")
  l=content(res2_raw, simplifyVector=T)$world
  xyzt=do.call(rbind, l)
  xyzt
}
